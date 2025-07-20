// applications/frontend/src/components/LoadingSpinner.js

import React from 'react';
import styled, { keyframes } from 'styled-components';

const spin = keyframes`
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
`;

const SpinnerContainer = styled.div`
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  ${props => props.fullscreen && `
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: linear-gradient(135deg, ${props.theme.colors.primary} 0%, ${props.theme.colors.secondary} 100%);
    z-index: 9999;
  `}
  ${props => !props.fullscreen && `
    padding: ${props.theme.spacing.xl};
  `}
`;

const Spinner = styled.div`
  width: ${props => props.size || '60px'};
  height: ${props => props.size || '60px'};
  border: 4px solid ${props => props.fullscreen ? 'rgba(255, 255, 255, 0.3)' : props.theme.colors.gray[200]};
  border-radius: 50%;
  border-top-color: ${props => props.fullscreen ? 'white' : props.theme.colors.primary};
  animation: ${spin} 1s ease-in-out infinite;
`;

const LoadingText = styled.div`
  color: ${props => props.fullscreen ? 'white' : props.theme.colors.gray[600]};
  font-size: 18px;
  font-weight: 500;
  margin-top: ${props => props.theme.spacing.lg};
  text-align: center;
`;

const LoadingSpinner = ({ fullscreen = false, text = 'Loading...', size = '60px' }) => {
  return (
    <SpinnerContainer fullscreen={fullscreen}>
      <Spinner fullscreen={fullscreen} size={size} />
      {text && <LoadingText fullscreen={fullscreen}>{text}</LoadingText>}
    </SpinnerContainer>
  );
};

export default LoadingSpinner;
