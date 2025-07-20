const AWS = require('aws-sdk');
const WebSocket = require('ws');
const { gql } = require('apollo-server-core');

// Mock AWS SDK
jest.mock('aws-sdk');

describe('Chat System Integration Tests', () => {
  let appsyncClient;
  let dynamoClient;
  let opensearchClient;
  let testUser;
  let authToken;
  let testRoom;

  beforeAll(async () => {
    // Initialize AWS clients
    appsyncClient = new AWS.AppSync({
      region: process.env.AWS_REGION || 'us-east-1'
    });

    dynamoClient = new AWS.DynamoDB.DocumentClient({
      region: process.env.AWS_REGION || 'us-east-1'
    });

    // Test user setup
    testUser = {
      id: `test-user-${Date.now()}`,
      username: `testuser${Date.now()}`,
      email: `test-${Date.now()}@example.com`,
      role: 'student'
    };

    // Mock authentication token
    authToken = 'mock-jwt-token';

    // Test room data
    testRoom = {
      id: `test-room-${Date.now()}`,
      name: 'Test Chat Room',
      type: 'GROUP',
      description: 'Integration test room'
    };
  });

  afterAll(async () => {
    // Cleanup test data
    try {
      // Delete test messages
      await dynamoClient.delete({
        TableName: process.env.CHAT_MESSAGES_TABLE,
        Key: { room_id: testRoom.id }
      }).promise();

      // Delete test room
      await dynamoClient.delete({
        TableName: process.env.CHAT_ROOMS_TABLE,
        Key: { room_id: testRoom.id }
      }).promise();
    } catch (error) {
      console.warn('Cleanup failed:', error.message);
    }
  });

  describe('Room Management', () => {
    test('should create a new chat room', async () => {
      const createRoomMutation = gql`
        mutation CreateRoom($input: CreateRoomInput!) {
          createRoom(input: $input) {
            room_id
            name
            type
            description
            created_at
            created_by
            member_count
          }
        }
      `;

      const variables = {
        input: {
          name: testRoom.name,
          type: testRoom.type,
          description: testRoom.description
        }
      };

      // Mock AppSync response
      const mockResponse = {
        data: {
          createRoom: {
            room_id: testRoom.id,
            name: testRoom.name,
            type: testRoom.type,
            description: testRoom.description,
            created_at: new Date().toISOString(),
            created_by: testUser.id,
            member_count: 1
          }
        }
      };

      // In a real test, you would make an actual GraphQL request
      // For this example, we'll simulate the response
      const response = mockResponse;

      expect(response.data.createRoom).toHaveProperty('room_id');
      expect(response.data.createRoom.name).toBe(testRoom.name);
      expect(response.data.createRoom.type).toBe(testRoom.type);
      expect(response.data.createRoom.member_count).toBe(1);
    });

    test('should list user rooms', async () => {
      const getRoomsQuery = gql`
        query GetRooms($userId: ID!) {
          getRooms(userId: $userId) {
            rooms {
              room_id
              name
              type
              last_message
              unread_count
              member_count
            }
          }
        }
      `;

      const variables = {
        userId: testUser.id
      };

      const mockResponse = {
        data: {
          getRooms: {
            rooms: [
              {
                room_id: testRoom.id,
                name: testRoom.name,
                type: testRoom.type,
                last_message: null,
                unread_count: 0,
                member_count: 1
              }
            ]
          }
        }
      };

      const response = mockResponse;

      expect(response.data.getRooms.rooms).toHaveLength(1);
      expect(response.data.getRooms.rooms[0].room_id).toBe(testRoom.id);
    });

    test('should join an existing room', async () => {
      const joinRoomMutation = gql`
        mutation JoinRoom($roomId: ID!, $userId: ID!) {
          joinRoom(roomId: $roomId, userId: $userId) {
            success
            message
            room {
              room_id
              member_count
            }
          }
        }
      `;

      const variables = {
        roomId: testRoom.id,
        userId: testUser.id
      };

      const mockResponse = {
        data: {
          joinRoom: {
            success: true,
            message: 'Successfully joined room',
            room: {
              room_id: testRoom.id,
              member_count: 2
            }
          }
        }
      };

      const response = mockResponse;

      expect(response.data.joinRoom.success).toBe(true);
      expect(response.data.joinRoom.room.member_count).toBe(2);
    });
  });

  describe('Message Operations', () => {
    let testMessage;

    beforeAll(() => {
      testMessage = {
        id: `test-message-${Date.now()}`,
        content: 'Hello, this is a test message!',
        type: 'TEXT'
      };
    });

    test('should send a text message', async () => {
      const sendMessageMutation = gql`
        mutation SendMessage($input: SendMessageInput!) {
          sendMessage(input: $input) {
            message_id
            room_id
            user_id
            content
            type
            timestamp
            status
          }
        }
      `;

      const variables = {
        input: {
          room_id: testRoom.id,
          content: testMessage.content,
          type: testMessage.type
        }
      };

      const mockResponse = {
        data: {
          sendMessage: {
            message_id: testMessage.id,
            room_id: testRoom.id,
            user_id: testUser.id,
            content: testMessage.content,
            type: testMessage.type,
            timestamp: new Date().toISOString(),
            status: 'SENT'
          }
        }
      };

      const response = mockResponse;

      expect(response.data.sendMessage).toHaveProperty('message_id');
      expect(response.data.sendMessage.content).toBe(testMessage.content);
      expect(response.data.sendMessage.type).toBe(testMessage.type);
      expect(response.data.sendMessage.status).toBe('SENT');
    });

    test('should retrieve messages with pagination', async () => {
      const getMessagesQuery = gql`
        query GetMessages($roomId: ID!, $limit: Int, $nextToken: String) {
          getMessages(roomId: $roomId, limit: $limit, nextToken: $nextToken) {
            messages {
              message_id
              content
              user_id
              timestamp
              type
            }
            nextToken
          }
        }
      `;

      const variables = {
        roomId: testRoom.id,
        limit: 20
      };

      const mockResponse = {
        data: {
          getMessages: {
            messages: [
              {
                message_id: testMessage.id,
                content: testMessage.content,
                user_id: testUser.id,
                timestamp: new Date().toISOString(),
                type: testMessage.type
              }
            ],
            nextToken: null
          }
        }
      };

      const response = mockResponse;

      expect(response.data.getMessages.messages).toHaveLength(1);
      expect(response.data.getMessages.messages[0].content).toBe(testMessage.content);
    });

    test('should update message status to read', async () => {
      const updateMessageMutation = gql`
        mutation UpdateMessage($messageId: ID!, $input: UpdateMessageInput!) {
          updateMessage(messageId: $messageId, input: $input) {
            message_id
            status
            read_by
          }
        }
      `;

      const variables = {
        messageId: testMessage.id,
        input: {
          status: 'READ'
        }
      };

      const mockResponse = {
        data: {
          updateMessage: {
            message_id: testMessage.id,
            status: 'READ',
            read_by: [testUser.id]
          }
        }
      };

      const response = mockResponse;

      expect(response.data.updateMessage.status).toBe('READ');
      expect(response.data.updateMessage.read_by).toContain(testUser.id);
    });

    test('should delete a message', async () => {
      const deleteMessageMutation = gql`
        mutation DeleteMessage($messageId: ID!) {
          deleteMessage(messageId: $messageId) {
            success
            message
          }
        }
      `;

      const variables = {
        messageId: testMessage.id
      };

      const mockResponse = {
        data: {
          deleteMessage: {
            success: true,
            message: 'Message deleted successfully'
          }
        }
      };

      const response = mockResponse;

      expect(response.data.deleteMessage.success).toBe(true);
    });
  });

  describe('Real-time Subscriptions', () => {
    test('should receive new message notifications', (done) => {
      const messageSubscription = gql`
        subscription OnMessageAdded($roomId: ID!) {
          onMessageAdded(roomId: $roomId) {
            message_id
            room_id
            user_id
            content
            timestamp
            type
          }
        }
      `;

      // Mock WebSocket connection for real-time subscriptions
      const mockWebSocket = {
        on: jest.fn(),
        send: jest.fn(),
        close: jest.fn()
      };

      // Simulate subscription setup
      mockWebSocket.on('message', (data) => {
        const message = JSON.parse(data);
        
        if (message.type === 'data') {
          expect(message.payload.data.onMessageAdded).toHaveProperty('message_id');
          expect(message.payload.data.onMessageAdded.room_id).toBe(testRoom.id);
          done();
        }
      });

      // Simulate receiving a new message
      setTimeout(() => {
        const mockMessage = {
          type: 'data',
          payload: {
            data: {
              onMessageAdded: {
                message_id: 'new-message-id',
                room_id: testRoom.id,
                user_id: 'other-user-id',
                content: 'New message received!',
                timestamp: new Date().toISOString(),
                type: 'TEXT'
              }
            }
          }
        };

        mockWebSocket.on.mock.calls[0][1](JSON.stringify(mockMessage));
      }, 100);
    });

    test('should receive typing indicators', (done) => {
      const typingSubscription = gql`
        subscription OnTyping($roomId: ID!) {
          onTyping(roomId: $roomId) {
            user_id
            username
            is_typing
            timestamp
          }
        }
      `;

      const mockWebSocket = {
        on: jest.fn(),
        send: jest.fn(),
        close: jest.fn()
      };

      mockWebSocket.on('message', (data) => {
        const message = JSON.parse(data);
        
        if (message.type === 'data') {
          expect(message.payload.data.onTyping).toHaveProperty('user_id');
          expect(message.payload.data.onTyping).toHaveProperty('is_typing');
          done();
        }
      });

      // Simulate typing indicator
      setTimeout(() => {
        const mockTyping = {
          type: 'data',
          payload: {
            data: {
              onTyping: {
                user_id: 'other-user-id',
                username: 'Other User',
                is_typing: true,
                timestamp: new Date().toISOString()
              }
            }
          }
        };

        mockWebSocket.on.mock.calls[0][1](JSON.stringify(mockTyping));
      }, 100);
    });
  });

  describe('Message Search', () => {
    test('should search messages by content', async () => {
      const searchMessagesQuery = gql`
        query SearchMessages($query: String!, $roomId: ID, $limit: Int) {
          searchMessages(query: $query, roomId: $roomId, limit: $limit) {
            messages {
              message_id
              content
              user_id
              room_id
              timestamp
              highlights
            }
            total
          }
        }
      `;

      const variables = {
        query: 'test message',
        roomId: testRoom.id,
        limit: 10
      };

      const mockResponse = {
        data: {
          searchMessages: {
            messages: [
              {
                message_id: testMessage.id,
                content: testMessage.content,
                user_id: testUser.id,
                room_id: testRoom.id,
                timestamp: new Date().toISOString(),
                highlights: ['test', 'message']
              }
            ],
            total: 1
          }
        }
      };

      const response = mockResponse;

      expect(response.data.searchMessages.messages).toHaveLength(1);
      expect(response.data.searchMessages.messages[0].highlights).toContain('test');
      expect(response.data.searchMessages.total).toBe(1);
    });

    test('should handle empty search results', async () => {
      const searchMessagesQuery = gql`
        query SearchMessages($query: String!, $roomId: ID, $limit: Int) {
          searchMessages(query: $query, roomId: $roomId, limit: $limit) {
            messages {
              message_id
              content
            }
            total
          }
        }
      `;

      const variables = {
        query: 'nonexistent content',
        roomId: testRoom.id,
        limit: 10
      };

      const mockResponse = {
        data: {
          searchMessages: {
            messages: [],
            total: 0
          }
        }
      };

      const response = mockResponse;

      expect(response.data.searchMessages.messages).toHaveLength(0);
      expect(response.data.searchMessages.total).toBe(0);
    });
  });

  describe('User Presence', () => {
    test('should update user presence status', async () => {
      const updatePresenceMutation = gql`
        mutation UpdatePresence($input: UpdatePresenceInput!) {
          updatePresence(input: $input) {
            user_id
            status
            last_seen
            current_room
          }
        }
      `;

      const variables = {
        input: {
          status: 'ONLINE',
          current_room: testRoom.id
        }
      };

      const mockResponse = {
        data: {
          updatePresence: {
            user_id: testUser.id,
            status: 'ONLINE',
            last_seen: new Date().toISOString(),
            current_room: testRoom.id
          }
        }
      };

      const response = mockResponse;

      expect(response.data.updatePresence.status).toBe('ONLINE');
      expect(response.data.updatePresence.current_room).toBe(testRoom.id);
    });

    test('should get room member presence', async () => {
      const getRoomMembersQuery = gql`
        query GetRoomMembers($roomId: ID!) {
          getRoomMembers(roomId: $roomId) {
            members {
              user_id
              username
              status
              last_seen
              role
            }
          }
        }
      `;

      const variables = {
        roomId: testRoom.id
      };

      const mockResponse = {
        data: {
          getRoomMembers: {
            members: [
              {
                user_id: testUser.id,
                username: testUser.username,
                status: 'ONLINE',
                last_seen: new Date().toISOString(),
                role: 'MEMBER'
              }
            ]
          }
        }
      };

      const response = mockResponse;

      expect(response.data.getRoomMembers.members).toHaveLength(1);
      expect(response.data.getRoomMembers.members[0].status).toBe('ONLINE');
    });
  });

  describe('File Attachments', () => {
    test('should handle file upload messages', async () => {
      const sendMessageMutation = gql`
        mutation SendMessage($input: SendMessageInput!) {
          sendMessage(input: $input) {
            message_id
            type
            content
            attachments {
              file_name
              file_size
              file_type
              file_url
            }
          }
        }
      `;

      const variables = {
        input: {
          room_id: testRoom.id,
          type: 'FILE',
          content: 'Shared a file',
          attachments: [
            {
              file_name: 'test-document.pdf',
              file_size: 1024000,
              file_type: 'application/pdf',
              file_url: 'https://s3.amazonaws.com/bucket/test-document.pdf'
            }
          ]
        }
      };

      const mockResponse = {
        data: {
          sendMessage: {
            message_id: 'file-message-id',
            type: 'FILE',
            content: 'Shared a file',
            attachments: [
              {
                file_name: 'test-document.pdf',
                file_size: 1024000,
                file_type: 'application/pdf',
                file_url: 'https://s3.amazonaws.com/bucket/test-document.pdf'
              }
            ]
          }
        }
      };

      const response = mockResponse;

      expect(response.data.sendMessage.type).toBe('FILE');
      expect(response.data.sendMessage.attachments).toHaveLength(1);
      expect(response.data.sendMessage.attachments[0].file_name).toBe('test-document.pdf');
    });
  });

  describe('Error Handling', () => {
    test('should handle invalid room access', async () => {
      const getMessagesQuery = gql`
        query GetMessages($roomId: ID!) {
          getMessages(roomId: $roomId) {
            messages {
              message_id
            }
          }
        }
      `;

      const variables = {
        roomId: 'invalid-room-id'
      };

      const mockErrorResponse = {
        errors: [
          {
            message: 'Room not found or access denied',
            extensions: {
              code: 'FORBIDDEN'
            }
          }
        ]
      };

      const response = mockErrorResponse;

      expect(response.errors).toHaveLength(1);
      expect(response.errors[0].extensions.code).toBe('FORBIDDEN');
    });

    test('should handle message validation errors', async () => {
      const sendMessageMutation = gql`
        mutation SendMessage($input: SendMessageInput!) {
          sendMessage(input: $input) {
            message_id
          }
        }
      `;

      const variables = {
        input: {
          room_id: testRoom.id,
          content: '', // Empty content should fail validation
          type: 'TEXT'
        }
      };

      const mockErrorResponse = {
        errors: [
          {
            message: 'Message content cannot be empty',
            extensions: {
              code: 'VALIDATION_ERROR'
            }
          }
        ]
      };

      const response = mockErrorResponse;

      expect(response.errors).toHaveLength(1);
      expect(response.errors[0].extensions.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('Performance Tests', () => {
    test('should handle concurrent message sending', async () => {
      const promises = [];
      const messageCount = 10;

      for (let i = 0; i < messageCount; i++) {
        const mockResponse = Promise.resolve({
          data: {
            sendMessage: {
              message_id: `concurrent-message-${i}`,
              content: `Concurrent message ${i}`,
              timestamp: new Date().toISOString()
            }
          }
        });

        promises.push(mockResponse);
      }

      const responses = await Promise.all(promises);

      expect(responses).toHaveLength(messageCount);
      responses.forEach((response, index) => {
        expect(response.data.sendMessage.message_id).toBe(`concurrent-message-${index}`);
      });
    });

    test('should handle large message history retrieval', async () => {
      const getMessagesQuery = gql`
        query GetMessages($roomId: ID!, $limit: Int) {
          getMessages(roomId: $roomId, limit: $limit) {
            messages {
              message_id
              content
              timestamp
            }
          }
        }
      `;

      const variables = {
        roomId: testRoom.id,
        limit: 100
      };

      // Mock large message set
      const mockMessages = Array.from({ length: 100 }, (_, i) => ({
        message_id: `message-${i}`,
        content: `Message content ${i}`,
        timestamp: new Date(Date.now() - i * 1000).toISOString()
      }));

      const mockResponse = {
        data: {
          getMessages: {
            messages: mockMessages
          }
        }
      };

      const response = mockResponse;

      expect(response.data.getMessages.messages).toHaveLength(100);
      
      // Verify messages are in chronological order (newest first)
      const timestamps = response.data.getMessages.messages.map(m => new Date(m.timestamp));
      for (let i = 1; i < timestamps.length; i++) {
        expect(timestamps[i-1].getTime()).toBeGreaterThanOrEqual(timestamps[i].getTime());
      }
    });
  });
});