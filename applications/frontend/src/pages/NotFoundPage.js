// applications/frontend/src/pages/NotFoundPage.js

import React from 'react';
import styled from 'styled-components';
import { Link } from 'react-router-dom';
import { Helmet } from 'react-helmet';

const NotFoundContainer = styled.div`
  min-height: calc(100vh - 8rem);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: ${props => props.theme.spacing.xl};
  text-align: center;
`;

const NotFoundContent = styled.div`
  max-width: 600px;
`;

const ErrorCode = styled.h1`
  font-size: 8rem;
  font-weight: 700;
  color: ${props => props.theme.colors.primary};
  margin-bottom: ${props => props.theme.spacing.lg};
  line-height: 1;

  @media (max-width: ${props => props.theme.breakpoints.mobile}) {
    font-size: 6rem;
  }
`;

const ErrorTitle = styled.h2`
  font-size: 2rem;
  margin-bottom: ${props => props.theme.spacing.md};
  color: ${props => props.theme.colors.gray[900]};
`;

const ErrorMessage = styled.p`
  font-size: 1.125rem;
  color: ${props => props.theme.colors.gray[600]};
  margin-bottom: ${props => props.theme.spacing.xl};
  line-height: 1.6;
`;

const HomeButton = styled(Link)`
  display: inline-block;
  background: ${props => props.theme.colors.primary};
  color: white;
  padding: ${props => props.theme.spacing.md} ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  font-weight: 600;
  text-decoration: none;
  transition: all 0.3s ease;

  &:hover {
    background: ${props => props.theme.colors.secondary};
    transform: translateY(-2px);
    box-shadow: ${props => props.theme.shadows.lg};
  }
`;

const NotFoundPage = () => {
  return (
    <>
      <Helmet>
        <title>Page Not Found - AWS Education Platform</title>
        <meta name="description" content="The page you're looking for doesn't exist." />
      </Helmet>

      <NotFoundContainer>
        <NotFoundContent>
          <ErrorCode>404</ErrorCode>
          <ErrorTitle>Page Not Found</ErrorTitle>
          <ErrorMessage>
            Sorry, we couldn't find the page you're looking for. 
            The page might have been moved, deleted, or the URL might be incorrect.
          </ErrorMessage>
          <HomeButton to="/">Return to Home</HomeButton>
        </NotFoundContent>
      </NotFoundContainer>
    </>
  );
};

export default NotFoundPage;
