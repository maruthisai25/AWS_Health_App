# AWS Education Platform Frontend

A modern React.js single-page application for the AWS Education Platform, featuring real-time chat, video lectures, attendance tracking, and grade management.

## Features

- 🔐 **Secure Authentication** - AWS Cognito integration with role-based access
- 📚 **Course Management** - Interactive course browser and enrollment
- 💬 **Real-time Chat** - Live chat rooms for each course
- 🎥 **Video Lectures** - High-quality video streaming with adaptive bitrate
- 📅 **Attendance Tracking** - Automated check-in with geolocation validation
- 📊 **Grade Management** - Comprehensive marks and progress tracking
- 📱 **Responsive Design** - Mobile-first design with PWA support
- ⚡ **Performance Optimized** - Code splitting, lazy loading, and CDN delivery

## Technology Stack

- **React 18** - Modern React with Hooks and Concurrent Features
- **React Router 6** - Client-side routing and navigation
- **Styled Components** - CSS-in-JS styling with theme support
- **AWS Amplify** - AWS SDK integration for authentication and API calls
- **Axios** - HTTP client for API requests
- **React Helmet** - Dynamic head management for SEO
- **Web Vitals** - Performance monitoring and optimization

## Quick Start

### Prerequisites

- Node.js 16+ and npm
- AWS account with deployed backend infrastructure

### Installation

1. **Clone and navigate to frontend directory**
   ```bash
   cd applications/frontend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env.local
   ```
   
   Update `.env.local` with your actual AWS configuration:
   ```bash
   # Get these values from Terraform outputs
   terraform output -json > config.json
   
   # Or manually from AWS Console
   REACT_APP_API_URL=https://your-api-gateway-url
   REACT_APP_USER_POOL_ID=your-cognito-user-pool-id
   REACT_APP_USER_POOL_CLIENT_ID=your-cognito-client-id
   ```

4. **Start development server**
   ```bash
   npm start
   ```

The application will be available at `http://localhost:3000`.

## Development

### Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── Header.js       # Navigation header
│   ├── Footer.js       # Site footer
│   ├── LoadingSpinner.js
│   └── ErrorBoundary.js
├── pages/              # Page components
│   ├── HomePage.js     # Landing page
│   ├── LoginPage.js    # User authentication
│   ├── DashboardPage.js # User dashboard
│   ├── CoursesPage.js  # Course management
│   ├── ChatPage.js     # Real-time chat
│   ├── VideoPage.js    # Video lectures
│   ├── AttendancePage.js
│   ├── MarksPage.js
│   └── ProfilePage.js
├── contexts/           # React Context providers
│   └── AuthContext.js  # Authentication state
├── App.js             # Main application component
└── index.js           # Application entry point
```

### Available Scripts

- `npm start` - Start development server
- `npm run build` - Build for production
- `npm test` - Run test suite
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier
- `npm run deploy` - Deploy to S3 bucket
- `npm run invalidate` - Invalidate CloudFront cache

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `REACT_APP_API_URL` | API Gateway endpoint | `https://api.yourdomain.com` |
| `REACT_APP_USER_POOL_ID` | Cognito User Pool ID | `us-east-1_abc123def` |
| `REACT_APP_USER_POOL_CLIENT_ID` | Cognito App Client ID | `1234567890abcdef` |
| `REACT_APP_AWS_REGION` | AWS Region | `us-east-1` |
| `REACT_APP_WEBSITE_URL` | CloudFront URL | `https://d123456.cloudfront.net` |

## Deployment

### Automatic Deployment

The application is automatically deployed via GitHub Actions when changes are pushed to the main branch.

### Manual Deployment

1. **Build the application**
   ```bash
   npm run build
   ```

2. **Deploy to S3**
   ```bash
   # Set environment variables
   export S3_BUCKET_NAME=your-s3-bucket-name
   export CLOUDFRONT_ID=your-cloudfront-distribution-id
   
   # Deploy
   npm run deploy
   npm run invalidate
   ```

3. **Verify deployment**
   - Check S3 bucket for updated files
   - Test website at CloudFront URL
   - Verify all features work correctly

## Authentication Flow

The application uses AWS Cognito for authentication:

1. **Registration** - Users register with email and role
2. **Email Verification** - Cognito sends verification email
3. **Login** - Users authenticate with email/password
4. **JWT Tokens** - Access and refresh tokens manage session
5. **Role-based Access** - Different permissions for students, teachers, admins

## Performance Optimization

### Code Splitting
```javascript
// Lazy load components
const ChatPage = lazy(() => import('./pages/ChatPage'));
const VideoPage = lazy(() => import('./pages/VideoPage'));
```

### Caching Strategy
- **Static Assets** - Cached by CloudFront for 1 year
- **HTML** - No cache, always fresh
- **API Responses** - Configurable cache headers

### Bundle Analysis
```bash
npm run build
npx bundle-analyzer build/static/js/*.js
```

## Testing

### Unit Tests
```bash
npm test
```

### Integration Tests
```bash
npm run test:integration
```

### E2E Tests
```bash
npm run test:e2e
```

## Browser Support

- Chrome 88+
- Firefox 78+
- Safari 13+
- Edge 88+

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure API Gateway has correct CORS configuration
   - Check frontend is using correct API URL

2. **Authentication Errors**
   - Verify Cognito configuration matches environment variables
   - Check token expiration and refresh logic

3. **Build Failures**
   - Clear node_modules and reinstall: `rm -rf node_modules && npm install`
   - Check for environment variable conflicts

4. **Deployment Issues**
   - Verify S3 bucket permissions
   - Check CloudFront distribution status
   - Ensure AWS credentials are configured

### Debug Mode

Enable debug logging:
```bash
REACT_APP_LOG_LEVEL=debug npm start
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please contact:
- Email: support@yourdomain.com
- Documentation: [docs.yourdomain.com](https://docs.yourdomain.com)
- Issues: [GitHub Issues](https://github.com/yourusername/aws-education-platform/issues)
