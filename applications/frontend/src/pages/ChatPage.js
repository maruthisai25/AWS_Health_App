// applications/frontend/src/pages/ChatPage.js

import React from 'react';
import styled from 'styled-components';
import { Helmet } from 'react-helmet';

const PageContainer = styled.div`
  max-width: 1280px;
  margin: 0 auto;
  padding: ${props => props.theme.spacing.xl};
`;

const PageTitle = styled.h1`
  font-size: 2.5rem;
  margin-bottom: ${props => props.theme.spacing.lg};
  color: ${props => props.theme.colors.gray[900]};
`;

const PlaceholderCard = styled.div`
  background: white;
  padding: ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  box-shadow: ${props => props.theme.shadows.md};
  text-align: center;

  h2 {
    color: ${props => props.theme.colors.primary};
    margin-bottom: ${props => props.theme.spacing.md};
  }

  p {
    color: ${props => props.theme.colors.gray[600]};
  }
`;

const ChatPage = () => {
  return (
    <>
      <Helmet>
        <title>Chat - AWS Education Platform</title>
      </Helmet>
      <PageContainer>
        <PageTitle>Chat Rooms</PageTitle>
        <PlaceholderCard>
          <h2>💬 Real-time Chat</h2>
          <p>Chat functionality will be implemented in Task 4 using AWS AppSync and DynamoDB.</p>
        </PlaceholderCard>
      </PageContainer>
    </>
  );
};

export default ChatPage;
