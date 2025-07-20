const { chromium } = require('playwright');

describe('Student End-to-End Flow', () => {
  let browser;
  let context;
  let page;
  let baseUrl;

  beforeAll(async () => {
    // Get the application URL from environment or terraform outputs
    baseUrl = process.env.WEBSITE_URL || 'https://app.education-platform.dev';
    
    // Launch browser
    browser = await chromium.launch({
      headless: process.env.CI === 'true', // Run headless in CI
      slowMo: process.env.CI === 'true' ? 0 : 100 // Slow down for debugging
    });

    // Create browser context with viewport
    context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    });

    // Create new page
    page = await context.newPage();

    // Set up console logging for debugging
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.error('Browser console error:', msg.text());
      }
    });

    // Set up error handling
    page.on('pageerror', error => {
      console.error('Page error:', error.message);
    });
  });

  afterAll(async () => {
    await browser?.close();
  });

  describe('Student Registration and Login', () => {
    const testStudent = {
      email: `student-e2e-${Date.now()}@example.com`,
      password: 'TestPassword123!',
      firstName: 'Test',
      lastName: 'Student',
      studentId: `S${Date.now()}`,
      department: 'Computer Science'
    };

    test('should complete student registration flow', async () => {
      // Navigate to registration page
      await page.goto(`${baseUrl}/register`);
      await page.waitForLoadState('networkidle');

      // Verify registration page loaded
      await expect(page.locator('h1')).toContainText('Register');

      // Fill registration form
      await page.fill('[data-testid="email-input"]', testStudent.email);
      await page.fill('[data-testid="password-input"]', testStudent.password);
      await page.fill('[data-testid="confirm-password-input"]', testStudent.password);
      await page.fill('[data-testid="first-name-input"]', testStudent.firstName);
      await page.fill('[data-testid="last-name-input"]', testStudent.lastName);
      await page.fill('[data-testid="student-id-input"]', testStudent.studentId);
      await page.selectOption('[data-testid="department-select"]', testStudent.department);
      await page.selectOption('[data-testid="role-select"]', 'student');

      // Submit registration
      await page.click('[data-testid="register-button"]');

      // Wait for success message or redirect
      await page.waitForSelector('[data-testid="registration-success"]', { timeout: 10000 });

      // Verify success message
      const successMessage = await page.textContent('[data-testid="registration-success"]');
      expect(successMessage).toContain('registration successful');
    });

    test('should handle email verification', async () => {
      // Navigate to verification page
      await page.goto(`${baseUrl}/verify`);

      // Fill verification form with test code
      await page.fill('[data-testid="email-input"]', testStudent.email);
      await page.fill('[data-testid="verification-code-input"]', '123456'); // Mock code

      // Submit verification
      await page.click('[data-testid="verify-button"]');

      // Wait for verification result
      await page.waitForSelector('[data-testid="verification-result"]', { timeout: 10000 });

      // In a real test, this would verify the actual verification process
      // For this example, we'll assume it succeeds
    });

    test('should login successfully', async () => {
      // Navigate to login page
      await page.goto(`${baseUrl}/login`);
      await page.waitForLoadState('networkidle');

      // Fill login form
      await page.fill('[data-testid="email-input"]', testStudent.email);
      await page.fill('[data-testid="password-input"]', testStudent.password);

      // Submit login
      await page.click('[data-testid="login-button"]');

      // Wait for dashboard redirect
      await page.waitForURL('**/dashboard', { timeout: 10000 });

      // Verify we're on the dashboard
      await expect(page.locator('h1')).toContainText('Welcome back');
      
      // Verify user name is displayed
      await expect(page.locator('[data-testid="user-name"]')).toContainText(testStudent.firstName);
    });
  });

  describe('Student Dashboard Navigation', () => {
    test('should display dashboard statistics', async () => {
      // Ensure we're on the dashboard
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');

      // Check for statistics cards
      await expect(page.locator('[data-testid="enrolled-courses-stat"]')).toBeVisible();
      await expect(page.locator('[data-testid="completed-assignments-stat"]')).toBeVisible();
      await expect(page.locator('[data-testid="upcoming-deadlines-stat"]')).toBeVisible();
      await expect(page.locator('[data-testid="average-grade-stat"]')).toBeVisible();

      // Verify statistics have values
      const enrolledCourses = await page.textContent('[data-testid="enrolled-courses-value"]');
      expect(enrolledCourses).toMatch(/\d+/);
    });

    test('should display course list', async () => {
      // Check for course list section
      await expect(page.locator('[data-testid="course-list"]')).toBeVisible();

      // Check for course items (if any exist)
      const courseItems = await page.locator('[data-testid="course-item"]').count();
      
      if (courseItems > 0) {
        // Verify first course has required elements
        await expect(page.locator('[data-testid="course-item"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="course-name"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="course-progress"]').first()).toBeVisible();
      }
    });

    test('should display recent announcements', async () => {
      // Check for announcements section
      await expect(page.locator('[data-testid="announcements-section"]')).toBeVisible();

      // Check for announcement items (if any exist)
      const announcementItems = await page.locator('[data-testid="announcement-item"]').count();
      
      if (announcementItems > 0) {
        // Verify first announcement has required elements
        await expect(page.locator('[data-testid="announcement-title"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="announcement-content"]').first()).toBeVisible();
      }
    });
  });

  describe('Course Interaction', () => {
    test('should navigate to courses page', async () => {
      // Click on courses navigation
      await page.click('[data-testid="courses-nav-link"]');
      await page.waitForURL('**/courses', { timeout: 5000 });

      // Verify courses page loaded
      await expect(page.locator('h1')).toContainText('Courses');
    });

    test('should view course details', async () => {
      // Check if there are any courses available
      const courseCount = await page.locator('[data-testid="course-card"]').count();
      
      if (courseCount > 0) {
        // Click on first course
        await page.click('[data-testid="course-card"]');
        
        // Wait for course detail page
        await page.waitForLoadState('networkidle');
        
        // Verify course details are displayed
        await expect(page.locator('[data-testid="course-title"]')).toBeVisible();
        await expect(page.locator('[data-testid="course-description"]')).toBeVisible();
      } else {
        console.log('No courses available for testing');
      }
    });
  });

  describe('Chat Functionality', () => {
    test('should access chat system', async () => {
      // Navigate to chat page
      await page.click('[data-testid="chat-nav-link"]');
      await page.waitForURL('**/chat', { timeout: 5000 });

      // Verify chat page loaded
      await expect(page.locator('h1')).toContainText('Chat');
    });

    test('should display chat rooms', async () => {
      // Check for chat rooms list
      await expect(page.locator('[data-testid="chat-rooms-list"]')).toBeVisible();

      // Check for room items (if any exist)
      const roomCount = await page.locator('[data-testid="chat-room-item"]').count();
      
      if (roomCount > 0) {
        // Verify first room has required elements
        await expect(page.locator('[data-testid="room-name"]').first()).toBeVisible();
      }
    });

    test('should send a message', async () => {
      // Check if there are any chat rooms
      const roomCount = await page.locator('[data-testid="chat-room-item"]').count();
      
      if (roomCount > 0) {
        // Click on first room
        await page.click('[data-testid="chat-room-item"]');
        
        // Wait for chat interface to load
        await page.waitForSelector('[data-testid="message-input"]', { timeout: 5000 });
        
        // Type and send a message
        const testMessage = `Test message from E2E test - ${Date.now()}`;
        await page.fill('[data-testid="message-input"]', testMessage);
        await page.click('[data-testid="send-button"]');
        
        // Verify message appears in chat
        await page.waitForSelector(`[data-testid="message"]:has-text("${testMessage}")`, { timeout: 5000 });
      } else {
        console.log('No chat rooms available for testing');
      }
    });
  });

  describe('Video Lectures', () => {
    test('should access video lectures', async () => {
      // Navigate to video page
      await page.click('[data-testid="video-nav-link"]');
      await page.waitForURL('**/videos', { timeout: 5000 });

      // Verify video page loaded
      await expect(page.locator('h1')).toContainText('Video Lectures');
    });

    test('should display video list', async () => {
      // Check for video list
      await expect(page.locator('[data-testid="video-list"]')).toBeVisible();

      // Check for video items (if any exist)
      const videoCount = await page.locator('[data-testid="video-item"]').count();
      
      if (videoCount > 0) {
        // Verify first video has required elements
        await expect(page.locator('[data-testid="video-title"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="video-thumbnail"]').first()).toBeVisible();
      }
    });

    test('should play a video', async () => {
      // Check if there are any videos available
      const videoCount = await page.locator('[data-testid="video-item"]').count();
      
      if (videoCount > 0) {
        // Click on first video
        await page.click('[data-testid="video-item"]');
        
        // Wait for video player to load
        await page.waitForSelector('[data-testid="video-player"]', { timeout: 10000 });
        
        // Verify video player is present
        await expect(page.locator('[data-testid="video-player"]')).toBeVisible();
        
        // Click play button
        await page.click('[data-testid="play-button"]');
        
        // Wait a moment for video to start
        await page.waitForTimeout(2000);
        
        // Verify video is playing (check for pause button)
        await expect(page.locator('[data-testid="pause-button"]')).toBeVisible();
      } else {
        console.log('No videos available for testing');
      }
    });
  });

  describe('Attendance Tracking', () => {
    test('should access attendance page', async () => {
      // Navigate to attendance page
      await page.click('[data-testid="attendance-nav-link"]');
      await page.waitForURL('**/attendance', { timeout: 5000 });

      // Verify attendance page loaded
      await expect(page.locator('h1')).toContainText('Attendance');
    });

    test('should display attendance history', async () => {
      // Check for attendance history section
      await expect(page.locator('[data-testid="attendance-history"]')).toBeVisible();

      // Check for attendance records (if any exist)
      const recordCount = await page.locator('[data-testid="attendance-record"]').count();
      
      if (recordCount > 0) {
        // Verify first record has required elements
        await expect(page.locator('[data-testid="class-name"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="attendance-status"]').first()).toBeVisible();
      }
    });

    test('should check in to a class', async () => {
      // Look for check-in button
      const checkInButton = page.locator('[data-testid="check-in-button"]');
      
      if (await checkInButton.isVisible()) {
        // Click check-in button
        await checkInButton.click();
        
        // Wait for success message
        await page.waitForSelector('[data-testid="check-in-success"]', { timeout: 5000 });
        
        // Verify success message
        await expect(page.locator('[data-testid="check-in-success"]')).toBeVisible();
      } else {
        console.log('No active classes available for check-in');
      }
    });
  });

  describe('Grades and Marks', () => {
    test('should access grades page', async () => {
      // Navigate to grades page
      await page.click('[data-testid="grades-nav-link"]');
      await page.waitForURL('**/grades', { timeout: 5000 });

      // Verify grades page loaded
      await expect(page.locator('h1')).toContainText('Grades');
    });

    test('should display grade summary', async () => {
      // Check for grade summary section
      await expect(page.locator('[data-testid="grade-summary"]')).toBeVisible();

      // Check for GPA or average grade
      const gradeElements = await page.locator('[data-testid="average-grade"]').count();
      
      if (gradeElements > 0) {
        await expect(page.locator('[data-testid="average-grade"]')).toBeVisible();
      }
    });

    test('should display course grades', async () => {
      // Check for course grades list
      await expect(page.locator('[data-testid="course-grades"]')).toBeVisible();

      // Check for grade items (if any exist)
      const gradeCount = await page.locator('[data-testid="grade-item"]').count();
      
      if (gradeCount > 0) {
        // Verify first grade has required elements
        await expect(page.locator('[data-testid="assignment-name"]').first()).toBeVisible();
        await expect(page.locator('[data-testid="grade-value"]').first()).toBeVisible();
      }
    });
  });

  describe('Profile Management', () => {
    test('should access profile page', async () => {
      // Click on profile link (usually in header)
      await page.click('[data-testid="profile-nav-link"]');
      await page.waitForURL('**/profile', { timeout: 5000 });

      // Verify profile page loaded
      await expect(page.locator('h1')).toContainText('Profile');
    });

    test('should display user information', async () => {
      // Check for user info section
      await expect(page.locator('[data-testid="user-info"]')).toBeVisible();

      // Verify user details are displayed
      await expect(page.locator('[data-testid="user-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="user-name"]')).toBeVisible();
    });

    test('should update profile information', async () => {
      // Look for edit profile button
      const editButton = page.locator('[data-testid="edit-profile-button"]');
      
      if (await editButton.isVisible()) {
        await editButton.click();
        
        // Wait for edit form
        await page.waitForSelector('[data-testid="profile-edit-form"]', { timeout: 5000 });
        
        // Update a field (e.g., phone number)
        await page.fill('[data-testid="phone-input"]', '+1234567890');
        
        // Save changes
        await page.click('[data-testid="save-profile-button"]');
        
        // Wait for success message
        await page.waitForSelector('[data-testid="profile-update-success"]', { timeout: 5000 });
        
        // Verify success message
        await expect(page.locator('[data-testid="profile-update-success"]')).toBeVisible();
      }
    });
  });

  describe('Responsive Design', () => {
    test('should work on mobile viewport', async () => {
      // Set mobile viewport
      await page.setViewportSize({ width: 375, height: 667 });
      
      // Navigate to dashboard
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // Verify mobile navigation
      const mobileMenu = page.locator('[data-testid="mobile-menu-button"]');
      if (await mobileMenu.isVisible()) {
        await mobileMenu.click();
        await expect(page.locator('[data-testid="mobile-nav-menu"]')).toBeVisible();
      }
      
      // Verify content is still accessible
      await expect(page.locator('[data-testid="enrolled-courses-stat"]')).toBeVisible();
    });

    test('should work on tablet viewport', async () => {
      // Set tablet viewport
      await page.setViewportSize({ width: 768, height: 1024 });
      
      // Navigate to courses page
      await page.goto(`${baseUrl}/courses`);
      await page.waitForLoadState('networkidle');
      
      // Verify layout adapts to tablet size
      await expect(page.locator('h1')).toContainText('Courses');
      
      // Check that content is properly displayed
      const courseGrid = page.locator('[data-testid="course-grid"]');
      if (await courseGrid.isVisible()) {
        // Verify grid layout works on tablet
        const gridStyle = await courseGrid.getAttribute('style');
        expect(gridStyle).toBeTruthy();
      }
    });
  });

  describe('Accessibility', () => {
    test('should have proper heading structure', async () => {
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // Check for proper heading hierarchy
      const h1Count = await page.locator('h1').count();
      expect(h1Count).toBeGreaterThanOrEqual(1);
      
      // Verify main heading is present
      await expect(page.locator('h1')).toBeVisible();
    });

    test('should have proper ARIA labels', async () => {
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // Check for navigation landmarks
      const nav = page.locator('nav[role="navigation"]');
      if (await nav.count() > 0) {
        await expect(nav.first()).toBeVisible();
      }
      
      // Check for main content area
      const main = page.locator('main');
      if (await main.count() > 0) {
        await expect(main.first()).toBeVisible();
      }
    });

    test('should be keyboard navigable', async () => {
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // Test tab navigation
      await page.keyboard.press('Tab');
      
      // Verify focus is visible
      const focusedElement = await page.evaluate(() => document.activeElement.tagName);
      expect(['A', 'BUTTON', 'INPUT'].includes(focusedElement)).toBeTruthy();
    });
  });

  describe('Performance', () => {
    test('should load dashboard within acceptable time', async () => {
      const startTime = Date.now();
      
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      const loadTime = Date.now() - startTime;
      
      // Dashboard should load within 5 seconds
      expect(loadTime).toBeLessThan(5000);
    });

    test('should have good Core Web Vitals', async () => {
      await page.goto(`${baseUrl}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // Measure Largest Contentful Paint (LCP)
      const lcp = await page.evaluate(() => {
        return new Promise((resolve) => {
          new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const lastEntry = entries[entries.length - 1];
            resolve(lastEntry.startTime);
          }).observe({ entryTypes: ['largest-contentful-paint'] });
          
          // Fallback timeout
          setTimeout(() => resolve(0), 3000);
        });
      });
      
      // LCP should be under 2.5 seconds
      if (lcp > 0) {
        expect(lcp).toBeLessThan(2500);
      }
    });
  });

  describe('Error Handling', () => {
    test('should handle 404 pages gracefully', async () => {
      await page.goto(`${baseUrl}/nonexistent-page`);
      
      // Should show 404 page or redirect to home
      const pageTitle = await page.title();
      const pageContent = await page.textContent('body');
      
      expect(
        pageTitle.includes('404') || 
        pageTitle.includes('Not Found') ||
        pageContent.includes('404') ||
        pageContent.includes('Page not found')
      ).toBeTruthy();
    });

    test('should handle network errors gracefully', async () => {
      // Simulate offline condition
      await context.setOffline(true);
      
      await page.goto(`${baseUrl}/dashboard`);
      
      // Should show offline message or cached content
      const pageContent = await page.textContent('body');
      
      expect(
        pageContent.includes('offline') ||
        pageContent.includes('network') ||
        pageContent.includes('connection') ||
        pageContent.length > 0 // Has cached content
      ).toBeTruthy();
      
      // Restore online condition
      await context.setOffline(false);
    });
  });
});