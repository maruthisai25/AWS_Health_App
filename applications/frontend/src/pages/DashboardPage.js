// applications/frontend/src/pages/DashboardPage.js

import React from 'react';
import styled from 'styled-components';
import { Helmet } from 'react-helmet';
import { useAuth } from '../contexts/AuthContext';

const DashboardContainer = styled.div`
  max-width: 1280px;
  margin: 0 auto;
  padding: ${props => props.theme.spacing.xl};
`;

const DashboardHeader = styled.div`
  margin-bottom: ${props => props.theme.spacing.xl};
`;

const WelcomeMessage = styled.h1`
  font-size: 2rem;
  margin-bottom: ${props => props.theme.spacing.md};
  color: ${props => props.theme.colors.gray[900]};
`;

const Subtitle = styled.p`
  color: ${props => props.theme.colors.gray[600]};
  font-size: 1.125rem;
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: ${props => props.theme.spacing.lg};
  margin-bottom: ${props => props.theme.spacing.xl};
`;

const StatCard = styled.div`
  background: white;
  padding: ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  box-shadow: ${props => props.theme.shadows.md};
  border-left: 4px solid ${props => props.theme.colors.primary};

  h3 {
    font-size: 2rem;
    font-weight: 700;
    color: ${props => props.theme.colors.primary};
    margin-bottom: ${props => props.theme.spacing.sm};
  }

  p {
    color: ${props => props.theme.colors.gray[600]};
    font-weight: 500;
  }
`;

const QuickActions = styled.div`
  background: white;
  padding: ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  box-shadow: ${props => props.theme.shadows.md};

  h2 {
    margin-bottom: ${props => props.theme.spacing.lg};
    color: ${props => props.theme.colors.gray[900]};
  }
`;

const ActionGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: ${props => props.theme.spacing.md};
`;

const ActionButton = styled.button`
  background: ${props => props.theme.colors.gray[50]};
  border: 1px solid ${props => props.theme.colors.gray[200]};
  padding: ${props => props.theme.spacing.lg};
  border-radius: ${props => props.theme.borderRadius.md};
  text-align: left;
  transition: all 0.2s ease;

  &:hover {
    background: ${props => props.theme.colors.primary};
    color: white;
    transform: translateY(-2px);
    box-shadow: ${props => props.theme.shadows.lg};
  }

  h3 {
    font-size: 1.125rem;
    font-weight: 600;
    margin-bottom: ${props => props.theme.spacing.sm};
  }

  p {
    color: ${props => props.theme.colors.gray[600]};
    font-size: 0.875rem;
  }

  &:hover p {
    color: rgba(255, 255, 255, 0.9);
  }
`;

const DashboardPage = () => {
  const { user } = useAuth();

  return (
    <>
      <Helmet>
        <title>Dashboard - AWS Education Platform</title>
        <meta name="description" content="Your personalized dashboard with course overview, stats, and quick actions." />
      </Helmet>

      <DashboardContainer>
        <DashboardHeader>
          <WelcomeMessage>Welcome back, {user?.email || 'Student'}!</WelcomeMessage>
          <Subtitle>Here's what's happening with your courses today.</Subtitle>
        </DashboardHeader>

        <StatsGrid>
          <StatCard>
            <h3>5</h3>
            <p>Active Courses</p>
          </StatCard>
          <StatCard>
            <h3>12</h3>
            <p>Assignments Due</p>
          </StatCard>
          <StatCard>
            <h3>89%</h3>
            <p>Attendance Rate</p>
          </StatCard>
          <StatCard>
            <h3>3.8</h3>
            <p>Average GPA</p>
          </StatCard>
        </StatsGrid>

        <QuickActions>
          <h2>Quick Actions</h2>
          <ActionGrid>
            <ActionButton>
              <h3>📚 View Courses</h3>
              <p>Access your enrolled courses and materials</p>
            </ActionButton>
            <ActionButton>
              <h3>💬 Join Chat</h3>
              <p>Connect with classmates and instructors</p>
            </ActionButton>
            <ActionButton>
              <h3>🎥 Watch Lectures</h3>
              <p>Catch up on recorded video lectures</p>
            </ActionButton>
            <ActionButton>
              <h3>📊 Check Grades</h3>
              <p>View your latest marks and progress</p>
            </ActionButton>
            <ActionButton>
              <h3>📅 Mark Attendance</h3>
              <p>Check in for today's classes</p>
            </ActionButton>
            <ActionButton>
              <h3>👤 Edit Profile</h3>
              <p>Update your account information</p>
            </ActionButton>
          </ActionGrid>
        </QuickActions>
      </DashboardContainer>
    </>
  );
};

export default DashboardPage;
