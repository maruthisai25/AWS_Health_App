const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { 
  DynamoDBDocumentClient, 
  GetCommand, 
  PutCommand, 
  UpdateCommand, 
  QueryCommand, 
  ScanCommand,
  DeleteCommand 
} = require('@aws-sdk/lib-dynamodb');
const { Client } = require('@opensearch-project/opensearch');
const { defaultProvider } = require('@aws-sdk/credential-provider-node');
const { AwsSigv4Signer } = require('@opensearch-project/opensearch/aws');

// Initialize AWS clients
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

// Initialize OpenSearch client if enabled
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

// Environment variables
const CHAT_MESSAGES_TABLE = process.env.CHAT_MESSAGES_TABLE;
const CHAT_ROOMS_TABLE = process.env.CHAT_ROOMS_TABLE;
const ROOM_MEMBERS_TABLE = process.env.ROOM_MEMBERS_TABLE;
const USER_PRESENCE_TABLE = process.env.USER_PRESENCE_TABLE;
const MAX_MESSAGE_LENGTH = parseInt(process.env.MAX_MESSAGE_LENGTH) || 1000;
const MAX_ROOM_MEMBERS = parseInt(process.env.MAX_ROOM_MEMBERS) || 100;

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

const generateId = () => {
  const timestamp = Date.now().toString(36);
  const randomPart = Math.random().toString(36).substr(2, 9);
  return `${timestamp}${randomPart}`;
};

const validateInput = (input, requiredFields) => {
  for (const field of requiredFields) {
    if (!input[field]) {
      throw new Error(`Missing required field: ${field}`);
    }
  }
};

// Main handler
exports.handler = async (event) => {
  logger.debug('Lambda event received', event);

  try {
    const { action } = event;

    switch (action) {
      case 'createRoom':
        return await createRoom(event);
      case 'getRooms':
        return await getUserRooms(event);
      case 'searchMessages':
        return await searchMessages(event);
      case 'getRoomMembers':
        return await getRoomMembers(event);
      case 'joinRoom':
        return await joinRoom(event);
      case 'leaveRoom':
        return await leaveRoom(event);
      case 'updateRoomSettings':
        return await updateRoomSettings(event);
      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    logger.error('Lambda execution error', error);
    return {
      errorMessage: error.message,
      errorType: error.constructor.name
    };
  }
};

// Create a new chat room
async function createRoom(event) {
  const { input, identity } = event;
  
  validateInput(input, ['name', 'roomType']);

  if (input.name.length > 100) {
    throw new Error('Room name too long (max 100 characters)');
  }

  const roomId = generateId();
  const timestamp = Date.now();
  const userId = identity.sub;

  // Default room settings
  const defaultSettings = {
    isPrivate: false,
    allowFileUploads: true,
    allowReactions: true,
    messageRetentionDays: 90,
    maxMembers: MAX_ROOM_MEMBERS,
    requireApproval: false,
    allowedFileTypes: ['image/jpeg', 'image/png', 'image/gif', 'application/pdf']
  };

  const roomData = {
    room_id: roomId,
    name: input.name,
    description: input.description || '',
    room_type: input.roomType,
    created_by: userId,
    created_at: timestamp,
    updated_at: timestamp,
    member_count: 1,
    settings: JSON.stringify({ ...defaultSettings, ...input.settings }),
    metadata: JSON.stringify(input.metadata || {}),
    last_activity: timestamp
  };

  // Create room record
  await docClient.send(new PutCommand({
    TableName: CHAT_ROOMS_TABLE,
    Item: roomData,
    ConditionExpression: 'attribute_not_exists(room_id)'
  }));

  // Add creator as room member in separate table
  const memberData = {
    room_id: roomId,
    user_id: userId,
    role: 'OWNER',
    joined_at: timestamp,
    permissions: ['SEND_MESSAGE', 'DELETE_MESSAGE', 'EDIT_MESSAGE', 'MANAGE_MEMBERS', 'MANAGE_SETTINGS', 'PIN_MESSAGE', 'UPLOAD_FILES']
  };

  await docClient.send(new PutCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Item: memberData
  }));

  // Add initial members if specified
  if (input.initialMembers && input.initialMembers.length > 0) {
    const memberPromises = [];
    for (const memberId of input.initialMembers.slice(0, MAX_ROOM_MEMBERS - 1)) {
      const initialMemberData = {
        room_id: roomId,
        user_id: memberId,
        role: 'MEMBER',
        joined_at: timestamp,
        permissions: ['SEND_MESSAGE']
      };

      memberPromises.push(
        docClient.send(new PutCommand({
          TableName: ROOM_MEMBERS_TABLE,
          Item: initialMemberData
        })).catch(error => {
          logger.error(`Failed to add initial member ${memberId}`, error);
        })
      );
    }

    await Promise.allSettled(memberPromises);

    // Update room member count
    await docClient.send(new UpdateCommand({
      TableName: CHAT_ROOMS_TABLE,
      Key: { room_id: roomId },
      UpdateExpression: 'SET member_count = :count',
      ExpressionAttributeValues: {
        ':count': 1 + input.initialMembers.length
      }
    }));
  }

  logger.info('Room created successfully', { roomId, userId });

  return {
    data: {
      roomId,
      name: input.name,
      description: input.description || '',
      roomType: input.roomType,
      createdBy: userId,
      createdAt: timestamp,
      updatedAt: timestamp,
      memberCount: 1 + (input.initialMembers?.length || 0),
      settings: { ...defaultSettings, ...input.settings },
      metadata: input.metadata || {}
    }
  };
}

// Search messages using OpenSearch
async function searchMessages(event) {
  if (!opensearchClient) {
    throw new Error('OpenSearch is not configured');
  }

  const { query, roomId, userId, messageType, fromDate, toDate, limit = 20, nextToken } = event;

  if (!query.trim()) {
    throw new Error('Search query cannot be empty');
  }

  // Build OpenSearch query
  const searchBody = {
    query: {
      bool: {
        must: [
          {
            multi_match: {
              query: query,
              fields: ['content^2', 'user_id', 'metadata'],
              fuzziness: 'AUTO',
              operator: 'and'
            }
          }
        ],
        filter: []
      }
    },
    sort: [
      { timestamp: { order: 'desc' } }
    ],
    size: Math.min(limit, 100),
    highlight: {
      fields: {
        content: {
          pre_tags: ['<mark>'],
          post_tags: ['</mark>']
        }
      }
    }
  };

  // Add filters
  if (roomId) {
    searchBody.query.bool.filter.push({ term: { room_id: roomId } });
  }

  if (userId) {
    searchBody.query.bool.filter.push({ term: { user_id: userId } });
  }

  if (messageType) {
    searchBody.query.bool.filter.push({ term: { message_type: messageType } });
  }

  if (fromDate || toDate) {
    const dateRange = {};
    if (fromDate) dateRange.gte = new Date(fromDate).getTime();
    if (toDate) dateRange.lte = new Date(toDate).getTime();
    
    searchBody.query.bool.filter.push({
      range: { timestamp: dateRange }
    });
  }

  // Handle pagination
  if (nextToken) {
    try {
      const decodedToken = JSON.parse(Buffer.from(nextToken, 'base64').toString());
      searchBody.search_after = decodedToken.search_after;
    } catch (error) {
      logger.error('Invalid nextToken', error);
    }
  }

  try {
    const response = await opensearchClient.search({
      index: 'chat-messages',
      body: searchBody
    });

    const hits = response.body.hits.hits;
    const messages = hits.map(hit => ({
      messageId: hit._source.message_id,
      roomId: hit._source.room_id,
      userId: hit._source.user_id,
      content: hit._source.content,
      messageType: hit._source.message_type,
      timestamp: hit._source.timestamp,
      editedAt: hit._source.edited_at,
      replyToMessageId: hit._source.reply_to_message_id,
      attachments: hit._source.attachments,
      metadata: hit._source.metadata,
      highlight: hit.highlight?.content?.[0] || null,
      score: hit._score
    }));

    // Generate next token if there are more results
    let newNextToken = null;
    if (hits.length === limit && hits.length > 0) {
      const lastHit = hits[hits.length - 1];
      newNextToken = Buffer.from(JSON.stringify({
        search_after: lastHit.sort
      })).toString('base64');
    }

    logger.info('Message search completed', { 
      query, 
      totalResults: response.body.hits.total.value,
      returnedResults: messages.length 
    });

    return {
      data: {
        items: messages,
        nextToken: newNextToken,
        total: response.body.hits.total.value
      }
    };

  } catch (error) {
    logger.error('OpenSearch query failed', error);
    throw new Error('Search temporarily unavailable');
  }
}

// Get room members
async function getRoomMembers(event) {
  const { roomId, limit = 100, nextToken } = event;

  if (!roomId) {
    throw new Error('Room ID is required');
  }

  const params = {
    TableName: ROOM_MEMBERS_TABLE,
    KeyConditionExpression: 'room_id = :roomId',
    ExpressionAttributeValues: {
      ':roomId': roomId
    },
    Limit: Math.min(limit, 100),
    ScanIndexForward: false
  };

  if (nextToken) {
    params.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
  }

  const result = await docClient.send(new QueryCommand(params));

  const members = result.Items.map(item => ({
    roomId: item.room_id,
    userId: item.user_id,
    role: item.role,
    joinedAt: item.joined_at,
    permissions: item.permissions || [],
    lastActivity: item.last_activity
  }));

  let newNextToken = null;
  if (result.LastEvaluatedKey) {
    newNextToken = Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64');
  }

  return {
    data: {
      items: members,
      nextToken: newNextToken,
      total: result.Count
    }
  };
}

// Join a room
async function joinRoom(event) {
  const { input, identity } = event;
  const { roomId } = input;
  const userId = identity.sub;

  if (!roomId) {
    throw new Error('Room ID is required');
  }

  // Check if room exists and get settings
  const roomResult = await docClient.send(new GetCommand({
    TableName: CHAT_ROOMS_TABLE,
    Key: { room_id: roomId }
  }));

  if (!roomResult.Item) {
    throw new Error('Room not found');
  }

  const room = roomResult.Item;
  const settings = JSON.parse(room.settings || '{}');

  // Check if room is at capacity
  if (room.member_count >= settings.maxMembers) {
    throw new Error('Room is at maximum capacity');
  }

  // Check if user is already a member
  const existingMember = await docClient.send(new GetCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Key: { room_id: roomId, user_id: userId }
  }));

  if (existingMember.Item) {
    throw new Error('User is already a member of this room');
  }

  const timestamp = Date.now();

  // Add user as member
  const memberData = {
    room_id: roomId,
    user_id: userId,
    role: 'MEMBER',
    joined_at: timestamp,
    permissions: ['SEND_MESSAGE']
  };

  await docClient.send(new PutCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Item: memberData
  }));

  // Update room member count
  await docClient.send(new UpdateCommand({
    TableName: CHAT_ROOMS_TABLE,
    Key: { room_id: roomId },
    UpdateExpression: 'SET member_count = member_count + :inc, last_activity = :timestamp',
    ExpressionAttributeValues: {
      ':inc': 1,
      ':timestamp': timestamp
    }
  }));

  logger.info('User joined room', { roomId, userId });

  return {
    data: {
      roomId,
      userId,
      role: 'MEMBER',
      joinedAt: timestamp,
      permissions: ['SEND_MESSAGE']
    }
  };
}

// Leave a room
async function leaveRoom(event) {
  const { input, identity } = event;
  const { roomId } = input;
  const userId = identity.sub;

  if (!roomId) {
    throw new Error('Room ID is required');
  }

  // Check if user is a member
  const memberResult = await docClient.send(new GetCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Key: { room_id: roomId, user_id: userId }
  }));

  if (!memberResult.Item) {
    throw new Error('User is not a member of this room');
  }

  const member = memberResult.Item;

  // Don't allow room owner to leave (they must transfer ownership first)
  if (member.role === 'OWNER') {
    throw new Error('Room owner cannot leave. Transfer ownership first.');
  }

  // Remove user from room
  await docClient.send(new DeleteCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Key: { room_id: roomId, user_id: userId }
  }));

  // Update room member count
  await docClient.send(new UpdateCommand({
    TableName: CHAT_ROOMS_TABLE,
    Key: { room_id: roomId },
    UpdateExpression: 'SET member_count = member_count - :dec, last_activity = :timestamp',
    ExpressionAttributeValues: {
      ':dec': 1,
      ':timestamp': Date.now()
    }
  }));

  logger.info('User left room', { roomId, userId });

  return { data: true };
}

// Update room settings
async function updateRoomSettings(event) {
  const { input, identity } = event;
  const { roomId, settings } = input;
  const userId = identity.sub;

  if (!roomId || !settings) {
    throw new Error('Room ID and settings are required');
  }

  // Check if user has permission to update settings
  const memberResult = await docClient.send(new GetCommand({
    TableName: ROOM_MEMBERS_TABLE,
    Key: { room_id: roomId, user_id: userId }
  }));

  if (!memberResult.Item) {
    throw new Error('User is not a member of this room');
  }

  const member = memberResult.Item;
  if (!member.permissions?.includes('MANAGE_SETTINGS')) {
    throw new Error('User does not have permission to manage room settings');
  }

  // Update room settings
  await docClient.send(new UpdateCommand({
    TableName: CHAT_ROOMS_TABLE,
    Key: { room_id: roomId },
    UpdateExpression: 'SET settings = :settings, updated_at = :timestamp',
    ExpressionAttributeValues: {
      ':settings': JSON.stringify(settings),
      ':timestamp': Date.now()
    }
  }));

  logger.info('Room settings updated', { roomId, userId });

  return {
    data: {
      roomId,
      settings,
      updatedBy: userId,
      updatedAt: Date.now()
    }
  };
}
// Add getUserRooms function to the existing chat resolver

// Get user's rooms (called by getRooms GraphQL query)
async function getUserRooms(event) {
  const { userId, roomType, limit = 50, nextToken } = event;

  if (!userId) {
    throw new Error('User ID is required');
  }

  // First, get user's room memberships
  const memberParams = {
    TableName: ROOM_MEMBERS_TABLE,
    IndexName: 'UserRoomsIndex',
    KeyConditionExpression: 'user_id = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    },
    Limit: Math.min(limit, 100),
    ScanIndexForward: false
  };

  if (nextToken) {
    memberParams.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
  }

  const memberResult = await docClient.send(new QueryCommand(memberParams));

  if (!memberResult.Items || memberResult.Items.length === 0) {
    return {
      data: {
        items: [],
        nextToken: null,
        total: 0
      }
    };
  }

  // Get room details for each membership
  const roomIds = memberResult.Items.map(item => item.room_id);
  const roomPromises = roomIds.map(roomId => 
    docClient.send(new GetCommand({
      TableName: CHAT_ROOMS_TABLE,
      Key: { room_id: roomId }
    })).catch(error => {
      logger.error(`Failed to get room ${roomId}`, error);
      return null;
    })
  );

  const roomResults = await Promise.allSettled(roomPromises);
  
  // Combine room data with membership data
  const rooms = [];
  for (let i = 0; i < memberResult.Items.length; i++) {
    const membership = memberResult.Items[i];
    const roomResult = roomResults[i];
    
    if (roomResult.status === 'fulfilled' && roomResult.value?.Item) {
      const room = roomResult.value.Item;
      
      // Apply room type filter if specified
      if (roomType && room.room_type !== roomType) {
        continue;
      }

      rooms.push({
        roomId: room.room_id,
        name: room.name,
        description: room.description || '',
        roomType: room.room_type,
        createdBy: room.created_by,
        createdAt: room.created_at,
        updatedAt: room.updated_at,
        memberCount: room.member_count,
        lastActivity: room.last_activity,
        settings: JSON.parse(room.settings || '{}'),
        metadata: JSON.parse(room.metadata || '{}'),
        // Add user's membership info
        userRole: membership.role,
        userJoinedAt: membership.joined_at,
        userPermissions: membership.permissions || []
      });
    }
  }

  let newNextToken = null;
  if (memberResult.LastEvaluatedKey) {
    newNextToken = Buffer.from(JSON.stringify(memberResult.LastEvaluatedKey)).toString('base64');
  }

  logger.info('User rooms retrieved', { userId, roomCount: rooms.length });

  return {
    data: {
      items: rooms,
      nextToken: newNextToken,
      total: rooms.length
    }
  };
}
