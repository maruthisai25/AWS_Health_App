// applications/frontend/src/pages/HomePage.js

import React from 'react';
import styled from 'styled-components';
import { Link } from 'react-router-dom';
import { Helmet } from 'react-helmet';

const HomeContainer = styled.div`
  min-height: calc(100vh - 8rem);
  background: linear-gradient(135deg, ${props => props.theme.colors.primary} 0%, ${props => props.theme.colors.secondary} 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  text-align: center;
  padding: ${props => props.theme.spacing.xl};
`;

const HeroContent = styled.div`
  max-width: 800px;
`;

const HeroTitle = styled.h1`
  font-size: 3.5rem;
  font-weight: 700;
  margin-bottom: ${props => props.theme.spacing.lg};
  color: white;

  @media (max-width: ${props => props.theme.breakpoints.mobile}) {
    font-size: 2.5rem;
  }
`;

const HeroSubtitle = styled.p`
  font-size: 1.25rem;
  margin-bottom: ${props => props.theme.spacing.xl};
  opacity: 0.9;
  line-height: 1.6;
`;

const CTAButtons = styled.div`
  display: flex;
  gap: ${props => props.theme.spacing.lg};
  justify-content: center;
  flex-wrap: wrap;
`;

const CTAButton = styled(Link)`
  display: inline-block;
  padding: ${props => props.theme.spacing.md} ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  font-weight: 600;
  text-decoration: none;
  transition: all 0.3s ease;
  min-width: 150px;

  ${props => props.primary && `
    background: white;
    color: ${props.theme.colors.primary};
    
    &:hover {
      background: ${props.theme.colors.gray[100]};
      transform: translateY(-2px);
      box-shadow: ${props.theme.shadows.lg};
    }
  `}

  ${props => props.secondary && `
    background: transparent;
    color: white;
    border: 2px solid white;
    
    &:hover {
      background: white;
      color: ${props.theme.colors.primary};
    }
  `}
`;

const FeatureSection = styled.div`
  background: white;
  padding: ${props => props.theme.spacing.xxl} ${props => props.theme.spacing.lg};
`;

const FeatureContainer = styled.div`
  max-width: 1280px;
  margin: 0 auto;
  text-align: center;
`;

const FeatureTitle = styled.h2`
  font-size: 2.5rem;
  margin-bottom: ${props => props.theme.spacing.xl};
  color: ${props => props.theme.colors.gray[900]};
`;

const FeatureGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: ${props => props.theme.spacing.xl};
  margin-top: ${props => props.theme.spacing.xl};
`;

const FeatureCard = styled.div`
  padding: ${props => props.theme.spacing.xl};
  border-radius: ${props => props.theme.borderRadius.lg};
  background: ${props => props.theme.colors.gray[50]};
  border: 1px solid ${props => props.theme.colors.gray[200]};
  transition: all 0.3s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: ${props => props.theme.shadows.lg};
  }

  h3 {
    font-size: 1.5rem;
    margin-bottom: ${props => props.theme.spacing.md};
    color: ${props => props.theme.colors.primary};
  }

  p {
    color: ${props => props.theme.colors.gray[600]};
    line-height: 1.6;
  }
`;

const HomePage = () => {
  return (
    <>
      <Helmet>
        <title>AWS Education Platform - Modern Online Learning</title>
        <meta name="description" content="Experience the future of education with our AWS-powered learning platform featuring live chat, video lectures, and attendance tracking." />
      </Helmet>

      <HomeContainer>
        <HeroContent>
          <HeroTitle>Welcome to the Future of Education</HeroTitle>
          <HeroSubtitle>
            Experience seamless online learning with real-time chat, high-quality video lectures, 
            automated attendance tracking, and comprehensive grade management - all powered by AWS.
          </HeroSubtitle>
          <CTAButtons>
            <CTAButton to="/register" primary>Get Started</CTAButton>
            <CTAButton to="/login" secondary>Sign In</CTAButton>
          </CTAButtons>
        </HeroContent>
      </HomeContainer>

      <FeatureSection>
        <FeatureContainer>
          <FeatureTitle>Powerful Features for Modern Learning</FeatureTitle>
          
          <FeatureGrid>
            <FeatureCard>
              <h3>🎥 Video Lectures</h3>
              <p>High-quality, scalable video streaming with automatic transcoding and adaptive bitrate for optimal viewing experience.</p>
            </FeatureCard>

            <FeatureCard>
              <h3>💬 Real-time Chat</h3>
              <p>Interactive chat rooms for every course with real-time messaging, file sharing, and collaborative discussions.</p>
            </FeatureCard>

            <FeatureCard>
              <h3>📊 Attendance Tracking</h3>
              <p>Automated attendance monitoring with geolocation validation, QR codes, and comprehensive reporting.</p>
            </FeatureCard>

            <FeatureCard>
              <h3>📈 Grade Management</h3>
              <p>Complete marks management system with detailed analytics, progress tracking, and performance insights.</p>
            </FeatureCard>

            <FeatureCard>
              <h3>🔐 Secure Authentication</h3>
              <p>Enterprise-grade security with AWS Cognito, multi-factor authentication, and role-based access control.</p>
            </FeatureCard>

            <FeatureCard>
              <h3>⚡ Scalable Infrastructure</h3>
              <p>Built on AWS with auto-scaling capabilities to handle any number of students and concurrent users.</p>
            </FeatureCard>
          </FeatureGrid>
        </FeatureContainer>
      </FeatureSection>
    </>
  );
};

export default HomePage;
