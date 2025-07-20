const request = require('supertest');
const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

// Mock AWS SDK
jest.mock('aws-sdk');

describe('Authentication Integration Tests', () => {
  let apiUrl;
  let cognitoClient;
  let testUser;

  beforeAll(async () => {
    // Get API URL from environment or terraform outputs
    apiUrl = process.env.API_GATEWAY_URL || 'https://api.education-platform.dev';
    
    // Initialize Cognito client
    cognitoClient = new AWS.CognitoIdentityServiceProvider({
      region: process.env.AWS_REGION || 'us-east-1'
    });

    // Test user data
    testUser = {
      email: `test-${Date.now()}@example.com`,
      password: 'TestPassword123!',
      role: 'student',
      student_id: `S${Date.now()}`,
      department: 'Computer Science'
    };
  });

  afterAll(async () => {
    // Cleanup: Delete test user if created
    if (testUser.username) {
      try {
        await cognitoClient.adminDeleteUser({
          UserPoolId: process.env.USER_POOL_ID,
          Username: testUser.username
        }).promise();
      } catch (error) {
        console.warn('Failed to cleanup test user:', error.message);
      }
    }
  });

  describe('User Registration', () => {
    test('should register a new student successfully', async () => {
      const response = await request(apiUrl)
        .post('/auth/register')
        .send(testUser)
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('userId');
      
      testUser.username = response.body.userId;
    });

    test('should reject registration with invalid email', async () => {
      const invalidUser = {
        ...testUser,
        email: 'invalid-email'
      };

      const response = await request(apiUrl)
        .post('/auth/register')
        .send(invalidUser)
        .expect(400);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('email');
    });

    test('should reject registration with weak password', async () => {
      const weakPasswordUser = {
        ...testUser,
        email: `weak-${Date.now()}@example.com`,
        password: '123'
      };

      const response = await request(apiUrl)
        .post('/auth/register')
        .send(weakPasswordUser)
        .expect(400);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('password');
    });

    test('should reject duplicate email registration', async () => {
      const duplicateUser = {
        ...testUser,
        student_id: `S${Date.now() + 1}`
      };

      const response = await request(apiUrl)
        .post('/auth/register')
        .send(duplicateUser)
        .expect(400);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('already exists');
    });
  });

  describe('Email Verification', () => {
    test('should verify email with valid confirmation code', async () => {
      // In a real test, you would need to get the confirmation code
      // from email or use a test confirmation code
      const mockConfirmationCode = '123456';

      // Mock the Cognito response for testing
      cognitoClient.confirmSignUp = jest.fn().mockReturnValue({
        promise: () => Promise.resolve({})
      });

      const response = await request(apiUrl)
        .post('/auth/verify')
        .send({
          username: testUser.email,
          confirmationCode: mockConfirmationCode
        })
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message');
    });

    test('should reject invalid confirmation code', async () => {
      const response = await request(apiUrl)
        .post('/auth/verify')
        .send({
          username: testUser.email,
          confirmationCode: 'invalid'
        })
        .expect(400);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
    });
  });

  describe('User Login', () => {
    let authTokens;

    beforeAll(async () => {
      // Ensure user is confirmed for login tests
      if (testUser.username) {
        try {
          await cognitoClient.adminConfirmSignUp({
            UserPoolId: process.env.USER_POOL_ID,
            Username: testUser.username
          }).promise();
        } catch (error) {
          // User might already be confirmed
        }
      }
    });

    test('should login with valid credentials', async () => {
      const response = await request(apiUrl)
        .post('/auth/login')
        .send({
          username: testUser.email,
          password: testUser.password
        })
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('tokens');
      expect(response.body.tokens).toHaveProperty('accessToken');
      expect(response.body.tokens).toHaveProperty('refreshToken');
      expect(response.body.tokens).toHaveProperty('idToken');
      expect(response.body).toHaveProperty('user');

      authTokens = response.body.tokens;

      // Verify JWT token structure
      const decodedToken = jwt.decode(authTokens.accessToken);
      expect(decodedToken).toHaveProperty('token_use', 'access');
      expect(decodedToken).toHaveProperty('username');
    });

    test('should reject login with invalid password', async () => {
      const response = await request(apiUrl)
        .post('/auth/login')
        .send({
          username: testUser.email,
          password: 'wrongpassword'
        })
        .expect(401);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Invalid');
    });

    test('should reject login with non-existent user', async () => {
      const response = await request(apiUrl)
        .post('/auth/login')
        .send({
          username: 'nonexistent@example.com',
          password: 'password123'
        })
        .expect(401);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
    });

    describe('Token Refresh', () => {
      test('should refresh tokens with valid refresh token', async () => {
        if (!authTokens?.refreshToken) {
          throw new Error('No refresh token available for test');
        }

        const response = await request(apiUrl)
          .post('/auth/refresh')
          .send({
            refreshToken: authTokens.refreshToken
          })
          .expect(200);

        expect(response.body).toHaveProperty('success', true);
        expect(response.body).toHaveProperty('tokens');
        expect(response.body.tokens).toHaveProperty('accessToken');
        expect(response.body.tokens).toHaveProperty('idToken');

        // New tokens should be different from old ones
        expect(response.body.tokens.accessToken).not.toBe(authTokens.accessToken);
      });

      test('should reject refresh with invalid token', async () => {
        const response = await request(apiUrl)
          .post('/auth/refresh')
          .send({
            refreshToken: 'invalid-refresh-token'
          })
          .expect(401);

        expect(response.body).toHaveProperty('success', false);
        expect(response.body).toHaveProperty('error');
      });
    });
  });

  describe('Protected Routes', () => {
    let validToken;

    beforeAll(async () => {
      // Get a valid token for protected route tests
      const loginResponse = await request(apiUrl)
        .post('/auth/login')
        .send({
          username: testUser.email,
          password: testUser.password
        });

      if (loginResponse.body.success) {
        validToken = loginResponse.body.tokens.accessToken;
      }
    });

    test('should access protected route with valid token', async () => {
      if (!validToken) {
        throw new Error('No valid token available for test');
      }

      const response = await request(apiUrl)
        .get('/auth/profile')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('user');
      expect(response.body.user).toHaveProperty('email', testUser.email);
    });

    test('should reject protected route without token', async () => {
      const response = await request(apiUrl)
        .get('/auth/profile')
        .expect(401);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('token');
    });

    test('should reject protected route with invalid token', async () => {
      const response = await request(apiUrl)
        .get('/auth/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
    });

    test('should reject expired token', async () => {
      // Create an expired token for testing
      const expiredToken = jwt.sign(
        { 
          username: testUser.email,
          exp: Math.floor(Date.now() / 1000) - 3600 // Expired 1 hour ago
        },
        'test-secret'
      );

      const response = await request(apiUrl)
        .get('/auth/profile')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(401);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('expired');
    });
  });

  describe('User Roles and Permissions', () => {
    test('should assign correct role during registration', async () => {
      const teacherUser = {
        email: `teacher-${Date.now()}@example.com`,
        password: 'TeacherPassword123!',
        role: 'teacher',
        department: 'Computer Science'
      };

      const response = await request(apiUrl)
        .post('/auth/register')
        .send(teacherUser)
        .expect(200);

      expect(response.body).toHaveProperty('success', true);

      // Login to verify role
      const loginResponse = await request(apiUrl)
        .post('/auth/login')
        .send({
          username: teacherUser.email,
          password: teacherUser.password
        });

      if (loginResponse.body.success) {
        const decodedToken = jwt.decode(loginResponse.body.tokens.idToken);
        expect(decodedToken).toHaveProperty('custom:role', 'teacher');
      }

      // Cleanup
      try {
        await cognitoClient.adminDeleteUser({
          UserPoolId: process.env.USER_POOL_ID,
          Username: response.body.userId
        }).promise();
      } catch (error) {
        console.warn('Failed to cleanup teacher test user:', error.message);
      }
    });

    test('should enforce role-based access control', async () => {
      // This test would verify that students can't access teacher-only endpoints
      // and vice versa. Implementation depends on your specific RBAC setup.
      
      if (!validToken) {
        throw new Error('No valid token available for test');
      }

      // Example: Student trying to access teacher-only endpoint
      const response = await request(apiUrl)
        .get('/teacher/courses')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(403);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('permission');
    });
  });

  describe('Password Reset', () => {
    test('should initiate password reset for valid email', async () => {
      const response = await request(apiUrl)
        .post('/auth/forgot-password')
        .send({
          username: testUser.email
        })
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('reset');
    });

    test('should handle password reset for non-existent email', async () => {
      const response = await request(apiUrl)
        .post('/auth/forgot-password')
        .send({
          username: 'nonexistent@example.com'
        })
        .expect(200); // Should return 200 for security reasons

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message');
    });
  });

  describe('Rate Limiting', () => {
    test('should enforce rate limiting on login attempts', async () => {
      const promises = [];
      
      // Make multiple rapid login attempts
      for (let i = 0; i < 10; i++) {
        promises.push(
          request(apiUrl)
            .post('/auth/login')
            .send({
              username: 'test@example.com',
              password: 'wrongpassword'
            })
        );
      }

      const responses = await Promise.all(promises);
      
      // At least some requests should be rate limited
      const rateLimitedResponses = responses.filter(res => res.status === 429);
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    });
  });

  describe('Security Headers', () => {
    test('should include security headers in responses', async () => {
      const response = await request(apiUrl)
        .get('/auth/health')
        .expect(200);

      // Check for common security headers
      expect(response.headers).toHaveProperty('x-content-type-options');
      expect(response.headers).toHaveProperty('x-frame-options');
      expect(response.headers).toHaveProperty('x-xss-protection');
    });
  });

  describe('CORS Configuration', () => {
    test('should handle CORS preflight requests', async () => {
      const response = await request(apiUrl)
        .options('/auth/login')
        .set('Origin', 'https://app.education-platform.com')
        .set('Access-Control-Request-Method', 'POST')
        .set('Access-Control-Request-Headers', 'Content-Type,Authorization')
        .expect(200);

      expect(response.headers).toHaveProperty('access-control-allow-origin');
      expect(response.headers).toHaveProperty('access-control-allow-methods');
      expect(response.headers).toHaveProperty('access-control-allow-headers');
    });
  });
});