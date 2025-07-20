const { Client } = require('@opensearch-project/opensearch');
const { defaultProvider } = require('@aws-sdk/credential-provider-node');
const { AwsSigv4Signer } = require('@opensearch-project/opensearch/aws');

// Initialize OpenSearch client
let opensearchClient = null;
if (process.env.OPENSEARCH_ENDPOINT) {
  opensearchClient = new Client({
    ...AwsSigv4Signer({
      credentials: defaultProvider(),
      region: process.env.AWS_REGION,
      service: 'es'
    }),
    node: `https://${process.env.OPENSEARCH_ENDPOINT}`
  });
}

// Utility functions
const logger = {
  info: (message, data) => console.log(JSON.stringify({ level: 'INFO', message, data, timestamp: new Date().toISOString() })),
  error: (message, error) => console.error(JSON.stringify({ level: 'ERROR', message, error: error.message, stack: error.stack, timestamp: new Date().toISOString() })),
  debug: (message, data) => {
    if (process.env.LOG_LEVEL === 'DEBUG') {
      console.log(JSON.stringify({ level: 'DEBUG', message, data, timestamp: new Date().toISOString() }));
    }
  }
};

// Main handler for DynamoDB Stream events
exports.handler = async (event) => {
  logger.debug('Message processor received DynamoDB stream event', { recordCount: event.Records.length });

  if (!opensearchClient) {
    logger.error('OpenSearch client not configured', {});
    return { statusCode: 500, body: 'OpenSearch not configured' };
  }

  const processedRecords = [];
  const failedRecords = [];

  for (const record of event.Records) {
    try {
      await processRecord(record);
      processedRecords.push(record.dynamodb.Keys);
    } catch (error) {
      logger.error('Failed to process DynamoDB record', error);
      failedRecords.push({
        recordId: record.dynamodb.Keys,
        error: error.message
      });
    }
  }

  logger.info('DynamoDB stream processing completed', {
    processedCount: processedRecords.length,
    failedCount: failedRecords.length
  });

  // Return processing results
  return {
    statusCode: 200,
    body: {
      processedRecords: processedRecords.length,
      failedRecords: failedRecords.length,
      errors: failedRecords
    }
  };
};

// Process individual DynamoDB stream record
async function processRecord(record) {
  const { eventName, dynamodb } = record;
  
  logger.debug('Processing DynamoDB record', { eventName, keys: dynamodb.Keys });

  switch (eventName) {
    case 'INSERT':
      await handleMessageInsert(dynamodb.NewImage);
      break;
    case 'MODIFY':
      await handleMessageUpdate(dynamodb.NewImage, dynamodb.OldImage);
      break;
    case 'REMOVE':
      await handleMessageDelete(dynamodb.OldImage);
      break;
    default:
      logger.debug('Ignoring event type', { eventName });
  }
}

// Handle new message insertion
async function handleMessageInsert(newImage) {
  if (!newImage || !newImage.message_id || !newImage.content) {
    logger.debug('Skipping record without required fields');
    return;
  }

  // Convert DynamoDB record to OpenSearch document
  const document = {
    message_id: newImage.message_id.S,
    room_id: newImage.room_id.S,
    user_id: newImage.user_id.S,
    content: newImage.content.S,
    message_type: newImage.message_type?.S || 'TEXT',
    timestamp: parseInt(newImage.timestamp.N),
    created_at: new Date(parseInt(newImage.timestamp.N)).toISOString(),
    edited_at: newImage.edited_at?.S ? new Date(newImage.edited_at.S).toISOString() : null,
    reply_to_message_id: newImage.reply_to_message_id?.S || null,
    attachments: newImage.attachments?.L ? parseAttachments(newImage.attachments.L) : [],
    metadata: newImage.metadata?.S ? JSON.parse(newImage.metadata.S) : {}
  };

  // Add text analysis fields
  document.content_length = document.content.length;
  document.word_count = document.content.split(/\s+/).length;
  document.has_attachments = document.attachments.length > 0;
  document.has_reply = !!document.reply_to_message_id;

  try {
    // Index document in OpenSearch
    const response = await opensearchClient.index({
      index: 'chat-messages',
      id: document.message_id,
      body: document,
      refresh: true
    });

    logger.info('Message indexed in OpenSearch', {
      messageId: document.message_id,
      roomId: document.room_id,
      indexResult: response.body.result
    });

  } catch (error) {
    logger.error('Failed to index message in OpenSearch', error);
    throw error;
  }
}

// Handle message update
async function handleMessageUpdate(newImage, oldImage) {
  if (!newImage || !newImage.message_id) {
    logger.debug('Skipping update record without required fields');
    return;
  }

  // Check if this is an actual content update
  const oldContent = oldImage?.content?.S;
  const newContent = newImage.content?.S;

  if (oldContent === newContent) {
    logger.debug('No content change detected, skipping update');
    return;
  }

  // Update the document in OpenSearch
  const document = {
    content: newContent,
    edited_at: newImage.edited_at?.S ? new Date(newImage.edited_at.S).toISOString() : new Date().toISOString(),
    content_length: newContent.length,
    word_count: newContent.split(/\s+/).length,
    metadata: newImage.metadata?.S ? JSON.parse(newImage.metadata.S) : {}
  };

  try {
    const response = await opensearchClient.update({
      index: 'chat-messages',
      id: newImage.message_id.S,
      body: {
        doc: document,
        doc_as_upsert: true
      },
      refresh: true
    });

    logger.info('Message updated in OpenSearch', {
      messageId: newImage.message_id.S,
      updateResult: response.body.result
    });

  } catch (error) {
    logger.error('Failed to update message in OpenSearch', error);
    throw error;
  }
}

// Handle message deletion
async function handleMessageDelete(oldImage) {
  if (!oldImage || !oldImage.message_id) {
    logger.debug('Skipping delete record without message ID');
    return;
  }

  try {
    const response = await opensearchClient.delete({
      index: 'chat-messages',
      id: oldImage.message_id.S,
      refresh: true
    });

    logger.info('Message deleted from OpenSearch', {
      messageId: oldImage.message_id.S,
      deleteResult: response.body.result
    });

  } catch (error) {
    if (error.body?.error?.type === 'not_found') {
      logger.debug('Message not found in OpenSearch (already deleted)', {
        messageId: oldImage.message_id.S
      });
    } else {
      logger.error('Failed to delete message from OpenSearch', error);
      throw error;
    }
  }
}

// Parse DynamoDB List of attachments
function parseAttachments(attachmentsList) {
  return attachmentsList.map(item => {
    const attachment = {};
    
    if (item.M) {
      for (const [key, value] of Object.entries(item.M)) {
        if (value.S) attachment[key] = value.S;
        if (value.N) attachment[key] = parseInt(value.N);
        if (value.BOOL) attachment[key] = value.BOOL;
      }
    }
    
    return attachment;
  });
}

// Initialize OpenSearch index with mapping (called during deployment)
async function initializeIndex() {
  if (!opensearchClient) {
    throw new Error('OpenSearch client not configured');
  }

  const indexName = 'chat-messages';
  
  // Check if index exists
  try {
    const exists = await opensearchClient.indices.exists({ index: indexName });
    if (exists.body) {
      logger.info('OpenSearch index already exists', { indexName });
      return;
    }
  } catch (error) {
    logger.debug('Index existence check failed, proceeding with creation');
  }

  // Create index with mapping
  const mapping = {
    mappings: {
      properties: {
        message_id: { type: 'keyword' },
        room_id: { type: 'keyword' },
        user_id: { type: 'keyword' },
        content: { 
          type: 'text',
          analyzer: 'standard',
          fields: {
            keyword: { type: 'keyword', ignore_above: 256 }
          }
        },
        message_type: { type: 'keyword' },
        timestamp: { type: 'long' },
        created_at: { type: 'date' },
        edited_at: { type: 'date' },
        reply_to_message_id: { type: 'keyword' },
        content_length: { type: 'integer' },
        word_count: { type: 'integer' },
        has_attachments: { type: 'boolean' },
        has_reply: { type: 'boolean' },
        attachments: {
          type: 'nested',
          properties: {
            fileName: { type: 'text' },
            fileSize: { type: 'long' },
            mimeType: { type: 'keyword' },
            url: { type: 'keyword' }
          }
        },
        metadata: { type: 'object', enabled: false }
      }
    },
    settings: {
      number_of_shards: 1,
      number_of_replicas: 0,
      analysis: {
        analyzer: {
          chat_analyzer: {
            type: 'standard',
            stopwords: '_english_'
          }
        }
      }
    }
  };

  try {
    const response = await opensearchClient.indices.create({
      index: indexName,
      body: mapping
    });

    logger.info('OpenSearch index created successfully', {
      indexName,
      acknowledged: response.body.acknowledged
    });

  } catch (error) {
    logger.error('Failed to create OpenSearch index', error);
    throw error;
  }
}

// Export initialization function for manual calls
exports.initializeIndex = initializeIndex;
