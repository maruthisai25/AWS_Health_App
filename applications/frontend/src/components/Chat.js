import React, { useState, useEffect, useRef, useContext } from 'react';
import styled from 'styled-components';
import { AuthContext } from '../contexts/AuthContext';

// Styled components
const ChatContainer = styled.div`
  display: flex;
  flex-direction: column;
  height: 100vh;
  max-height: 600px;
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: 8px;
  background: ${props => props.theme.colors.background};
  overflow: hidden;
`;

const ChatHeader = styled.div`
  padding: 1rem;
  background: ${props => props.theme.colors.primary};
  color: white;
  border-bottom: 1px solid ${props => props.theme.colors.border};
  
  h3 {
    margin: 0;
    font-size: 1.1rem;
  }
  
  .room-info {
    font-size: 0.8rem;
    opacity: 0.9;
    margin-top: 0.25rem;
  }
`;

const MessagesContainer = styled.div`
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
  background: ${props => props.theme.colors.background};
`;

const Message = styled.div`
  margin-bottom: 1rem;
  padding: 0.75rem;
  border-radius: 8px;
  background: ${props => props.isOwn ? props.theme.colors.primary : props.theme.colors.surface};
  color: ${props => props.isOwn ? 'white' : props.theme.colors.text};
  margin-left: ${props => props.isOwn ? '20%' : '0'};
  margin-right: ${props => props.isOwn ? '0' : '20%'};
  
  .message-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
    font-size: 0.8rem;
    opacity: 0.8;
  }
  
  .message-content {
    line-height: 1.4;
  }
  
  .message-time {
    font-size: 0.7rem;
    margin-top: 0.25rem;
    opacity: 0.7;
  }
`;

const InputContainer = styled.div`
  padding: 1rem;
  border-top: 1px solid ${props => props.theme.colors.border};
  background: ${props => props.theme.colors.surface};
`;

const MessageInput = styled.div`
  display: flex;
  gap: 0.5rem;
  
  input {
    flex: 1;
    padding: 0.75rem;
    border: 1px solid ${props => props.theme.colors.border};
    border-radius: 4px;
    outline: none;
    
    &:focus {
      border-color: ${props => props.theme.colors.primary};
    }
  }
  
  button {
    padding: 0.75rem 1.5rem;
    background: ${props => props.theme.colors.primary};
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    
    &:hover {
      opacity: 0.9;
    }
    
    &:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
  }
`;

const TypingIndicator = styled.div`
  padding: 0.5rem;
  font-size: 0.8rem;
  font-style: italic;
  color: ${props => props.theme.colors.textSecondary};
  min-height: 1.5rem;
`;

const UserList = styled.div`
  padding: 0.5rem;
  background: ${props => props.theme.colors.surface};
  border-top: 1px solid ${props => props.theme.colors.border};
  
  .user-item {
    display: inline-flex;
    align-items: center;
    margin-right: 1rem;
    font-size: 0.8rem;
    
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      margin-right: 0.25rem;
      background: ${props => props.online ? '#4CAF50' : '#ccc'};
    }
  }
`;

const LoadingSpinner = styled.div`
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 2rem;
  
  .spinner {
    width: 24px;
    height: 24px;
    border: 2px solid ${props => props.theme.colors.border};
    border-top: 2px solid ${props => props.theme.colors.primary};
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
`;

// Mock GraphQL client (replace with actual AppSync client)
const mockGraphQLClient = {
  query: async (query, variables) => {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    if (query.includes('getMessages')) {
      return {
        data: {
          getMessages: {
            items: [
              {
                messageId: '1',
                userId: 'user1',
                content: 'Hello everyone! Welcome to the chat.',
                timestamp: Date.now() - 300000,
                messageType: 'TEXT',
                user: { username: 'teacher@example.com', displayName: 'Professor Smith' }
              },
              {
                messageId: '2',
                userId: 'user2',
                content: 'Thanks! Excited to be here.',
                timestamp: Date.now() - 200000,
                messageType: 'TEXT',
                user: { username: 'student1@example.com', displayName: 'Alice Johnson' }
              },
              {
                messageId: '3',
                userId: 'user3',
                content: 'Does anyone have questions about the assignment?',
                timestamp: Date.now() - 100000,
                messageType: 'TEXT',
                user: { username: 'student2@example.com', displayName: 'Bob Wilson' }
              }
            ],
            nextToken: null,
            total: 3
          }
        }
      };
    }
    
    if (query.includes('getRooms')) {
      return {
        data: {
          getRooms: {
            items: [
              {
                roomId: 'room1',
                name: 'Computer Science 101',
                roomType: 'COURSE',
                memberCount: 25,
                lastActivity: Date.now() - 100000
              }
            ]
          }
        }
      };
    }
    
    return { data: {} };
  },
  
  mutate: async (mutation, variables) => {
    await new Promise(resolve => setTimeout(resolve, 300));
    
    if (mutation.includes('sendMessage')) {
      return {
        data: {
          sendMessage: {
            messageId: Date.now().toString(),
            userId: variables.input.userId || 'current-user',
            content: variables.input.content,
            timestamp: Date.now(),
            messageType: 'TEXT'
          }
        }
      };
    }
    
    return { data: {} };
  },
  
  subscribe: (subscription, variables, callback) => {
    // Mock subscription
    const interval = setInterval(() => {
      if (Math.random() > 0.7) {
        callback({
          data: {
            onMessageAdded: {
              messageId: Date.now().toString(),
              userId: 'user' + Math.floor(Math.random() * 10),
              content: 'This is a real-time message!',
              timestamp: Date.now(),
              messageType: 'TEXT',
              user: { username: 'someone@example.com', displayName: 'Someone' }
            }
          }
        });
      }
    }, 10000);
    
    return () => clearInterval(interval);
  }
};

// Main Chat component
const Chat = ({ roomId = 'room1', className }) => {
  const { user } = useContext(AuthContext);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [roomInfo, setRoomInfo] = useState(null);
  const [typingUsers, setTypingUsers] = useState([]);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const messagesEndRef = useRef(null);
  const typingTimeoutRef = useRef(null);

  // Load initial messages and room info
  useEffect(() => {
    loadMessages();
    loadRoomInfo();
  }, [roomId]);

  // Set up real-time subscriptions
  useEffect(() => {
    if (!roomId) return;

    // Subscribe to new messages
    const unsubscribeMessages = mockGraphQLClient.subscribe(
      `subscription OnMessageAdded($roomId: ID!) {
        onMessageAdded(roomId: $roomId) {
          messageId
          userId
          content
          timestamp
          messageType
          user {
            username
            displayName
          }
        }
      }`,
      { roomId },
      (result) => {
        if (result.data?.onMessageAdded) {
          setMessages(prev => [...prev, result.data.onMessageAdded]);
        }
      }
    );

    // Subscribe to typing indicators
    const unsubscribeTyping = mockGraphQLClient.subscribe(
      `subscription OnTyping($roomId: ID!) {
        onTyping(roomId: $roomId) {
          userId
          isTyping
          user {
            displayName
          }
        }
      }`,
      { roomId },
      (result) => {
        if (result.data?.onTyping) {
          const { userId, isTyping, user: typingUser } = result.data.onTyping;
          setTypingUsers(prev => {
            if (isTyping) {
              return [...prev.filter(u => u.userId !== userId), { userId, displayName: typingUser.displayName }];
            } else {
              return prev.filter(u => u.userId !== userId);
            }
          });
        }
      }
    );

    return () => {
      unsubscribeMessages();
      unsubscribeTyping();
    };
  }, [roomId]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const loadMessages = async () => {
    try {
      setLoading(true);
      const result = await mockGraphQLClient.query(
        `query GetMessages($roomId: ID!, $limit: Int) {
          getMessages(roomId: $roomId, limit: $limit) {
            items {
              messageId
              userId
              content
              timestamp
              messageType
              editedAt
              user {
                username
                displayName
              }
            }
            nextToken
            total
          }
        }`,
        { roomId, limit: 50 }
      );
      
      setMessages(result.data.getMessages.items || []);
    } catch (error) {
      console.error('Failed to load messages:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadRoomInfo = async () => {
    try {
      const result = await mockGraphQLClient.query(
        `query GetRoom($roomId: ID!) {
          getRoom(roomId: $roomId) {
            roomId
            name
            roomType
            memberCount
            lastActivity
          }
        }`,
        { roomId }
      );
      
      setRoomInfo(result.data.getRoom);
    } catch (error) {
      console.error('Failed to load room info:', error);
    }
  };

  const sendMessage = async () => {
    if (!newMessage.trim() || sending) return;
    
    try {
      setSending(true);
      
      const result = await mockGraphQLClient.mutate(
        `mutation SendMessage($input: SendMessageInput!) {
          sendMessage(input: $input) {
            messageId
            userId
            content
            timestamp
            messageType
            user {
              username
              displayName
            }
          }
        }`,
        {
          input: {
            roomId,
            content: newMessage.trim(),
            messageType: 'TEXT'
          }
        }
      );
      
      // Add message optimistically (it will also come via subscription)
      if (result.data?.sendMessage) {
        setMessages(prev => [...prev, {
          ...result.data.sendMessage,
          user: { 
            username: user?.email || 'unknown',
            displayName: user?.name || user?.email || 'You'
          }
        }]);
      }
      
      setNewMessage('');
      
    } catch (error) {
      console.error('Failed to send message:', error);
    } finally {
      setSending(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const handleInputChange = (e) => {
    setNewMessage(e.target.value);
    
    // Handle typing indicator
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    
    // Send typing indicator (mock implementation)
    typingTimeoutRef.current = setTimeout(() => {
      // Send stop typing in real implementation
    }, 2000);
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const formatTime = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatRelativeTime = (timestamp) => {
    const now = Date.now();
    const diff = now - timestamp;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    return `${days}d ago`;
  };

  if (loading) {
    return (
      <ChatContainer className={className}>
        <LoadingSpinner>
          <div className="spinner" />
        </LoadingSpinner>
      </ChatContainer>
    );
  }

  return (
    <ChatContainer className={className}>
      <ChatHeader>
        <h3>{roomInfo?.name || 'Chat Room'}</h3>
        <div className="room-info">
          {roomInfo?.memberCount} members • Last active {formatRelativeTime(roomInfo?.lastActivity || Date.now())}
        </div>
      </ChatHeader>

      <MessagesContainer>
        {messages.map((message) => (
          <Message 
            key={message.messageId} 
            isOwn={message.userId === user?.sub}
          >
            <div className="message-header">
              <span>{message.user?.displayName || message.user?.username || 'Unknown User'}</span>
              <span>{formatTime(message.timestamp)}</span>
            </div>
            <div className="message-content">{message.content}</div>
            {message.editedAt && (
              <div className="message-time">
                Edited {formatRelativeTime(message.editedAt)}
              </div>
            )}
          </Message>
        ))}
        <div ref={messagesEndRef} />
      </MessagesContainer>

      <TypingIndicator>
        {typingUsers.length > 0 && (
          <span>
            {typingUsers.map(u => u.displayName).join(', ')} 
            {typingUsers.length === 1 ? ' is' : ' are'} typing...
          </span>
        )}
      </TypingIndicator>

      <UserList>
        {onlineUsers.map(user => (
          <div key={user.userId} className="user-item">
            <div className="status-dot" online={user.status === 'ONLINE'} />
            {user.displayName}
          </div>
        ))}
      </UserList>

      <InputContainer>
        <MessageInput>
          <input
            type="text"
            value={newMessage}
            onChange={handleInputChange}
            onKeyPress={handleKeyPress}
            placeholder="Type a message..."
            disabled={sending}
            maxLength={1000}
          />
          <button 
            onClick={sendMessage} 
            disabled={!newMessage.trim() || sending}
          >
            {sending ? 'Sending...' : 'Send'}
          </button>
        </MessageInput>
      </InputContainer>
    </ChatContainer>
  );
};

export default Chat;
