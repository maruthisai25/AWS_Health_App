// applications/frontend/src/components/Footer.js

import React from 'react';
import styled from 'styled-components';
import { Link } from 'react-router-dom';

const FooterContainer = styled.footer`
  background: ${props => props.theme.colors.gray[900]};
  color: ${props => props.theme.colors.gray[300]};
  padding: ${props => props.theme.spacing.xl} 0;
  margin-top: auto;
`;

const FooterContent = styled.div`
  max-width: 1280px;
  margin: 0 auto;
  padding: 0 ${props => props.theme.spacing.lg};
`;

const FooterGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: ${props => props.theme.spacing.xl};
  margin-bottom: ${props => props.theme.spacing.xl};
`;

const FooterSection = styled.div`
  h3 {
    color: white;
    font-size: 1.125rem;
    font-weight: 600;
    margin-bottom: ${props => props.theme.spacing.md};
  }

  ul {
    list-style: none;
    padding: 0;
  }

  li {
    margin-bottom: ${props => props.theme.spacing.sm};
  }

  a {
    color: ${props => props.theme.colors.gray[400]};
    transition: color 0.2s ease;

    &:hover {
      color: ${props => props.theme.colors.primary};
    }
  }
`;

const Copyright = styled.div`
  text-align: center;
  padding-top: ${props => props.theme.spacing.lg};
  border-top: 1px solid ${props => props.theme.colors.gray[700]};
  color: ${props => props.theme.colors.gray[500]};
`;

const Footer = () => {
  return (
    <FooterContainer>
      <FooterContent>
        <FooterGrid>
          <FooterSection>
            <h3>Platform</h3>
            <ul>
              <li><Link to="/courses">Courses</Link></li>
              <li><Link to="/chat">Chat Rooms</Link></li>
              <li><Link to="/attendance">Attendance</Link></li>
              <li><Link to="/marks">Marks & Grades</Link></li>
            </ul>
          </FooterSection>

          <FooterSection>
            <h3>Support</h3>
            <ul>
              <li><a href="/help">Help Center</a></li>
              <li><a href="/contact">Contact Us</a></li>
              <li><a href="/faq">FAQ</a></li>
              <li><a href="/documentation">Documentation</a></li>
            </ul>
          </FooterSection>

          <FooterSection>
            <h3>Legal</h3>
            <ul>
              <li><a href="/privacy">Privacy Policy</a></li>
              <li><a href="/terms">Terms of Service</a></li>
              <li><a href="/accessibility">Accessibility</a></li>
              <li><a href="/cookies">Cookie Policy</a></li>
            </ul>
          </FooterSection>

          <FooterSection>
            <h3>Connect</h3>
            <ul>
              <li><a href="https://github.com" target="_blank" rel="noopener noreferrer">GitHub</a></li>
              <li><a href="https://twitter.com" target="_blank" rel="noopener noreferrer">Twitter</a></li>
              <li><a href="https://linkedin.com" target="_blank" rel="noopener noreferrer">LinkedIn</a></li>
              <li><a href="/blog">Blog</a></li>
            </ul>
          </FooterSection>
        </FooterGrid>

        <Copyright>
          <p>&copy; 2024 AWS Education Platform. All rights reserved. Built with ❤️ on AWS.</p>
        </Copyright>
      </FooterContent>
    </FooterContainer>
  );
};

export default Footer;
