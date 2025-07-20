import React, { useState, useEffect } from 'react';
import styled from 'styled-components';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';

const DashboardContainer = styled.div`
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  
  @media (max-width: 768px) {
    padding: 1rem;
  }
`;

const WelcomeSection = styled.div`
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  border-radius: 12px;
  margin-bottom: 2rem;
  
  h1 {
    margin: 0 0 0.5rem 0;
    font-size: 2rem;
  }
  
  p {
    margin: 0;
    opacity: 0.9;
  }
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
`;

const StatCard = styled.div`
  background: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  border-left: 4px solid ${props => props.color || '#667eea'};
  
  h3 {
    margin: 0 0 0.5rem 0;
    color: #333;
    font-size: 0.9rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  
  .value {
    font-size: 2rem;
    font-weight: bold;
    color: ${props => props.color || '#667eea'};
    margin-bottom: 0.5rem;
  }
  
  .change {
    font-size: 0.8rem;
    color: #666;
  }
`;

const ContentGrid = styled.div`
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 2rem;
  
  @media (max-width: 968px) {
    grid-template-columns: 1fr;
  }
`;

const MainContent = styled.div`
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
`;

const Sidebar = styled.div`
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
`;

const Card = styled.div`
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  overflow: hidden;
`;

const CardHeader = styled.div`
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #eee;
  
  h2 {
    margin: 0;
    font-size: 1.2rem;
    color: #333;
  }
`;

const CardContent = styled.div`
  padding: 1.5rem;
`;

const CourseList = styled.div`
  display: flex;
  flex-direction: column;
  gap: 1rem;
`;

const CourseItem = styled.div`
  display: flex;
  align-items: center;
  padding: 1rem;
  border: 1px solid #eee;
  border-radius: 6px;
  transition: all 0.2s ease;
  
  &:hover {
    border-color: #667eea;
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  }
`;

const CourseIcon = styled.div`
  width: 48px;
  height: 48px;
  border-radius: 8px;
  background: ${props => props.color || '#667eea'};
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  margin-right: 1rem;
`;

const CourseInfo = styled.div`
  flex: 1;
  
  h3 {
    margin: 0 0 0.25rem 0;
    font-size: 1rem;
    color: #333;
  }
  
  p {
    margin: 0;
    font-size: 0.85rem;
    color: #666;
  }
`;

const CourseProgress = styled.div`
  text-align: right;
  
  .percentage {
    font-weight: bold;
    color: #667eea;
    margin-bottom: 0.25rem;
  }
  
  .progress-bar {
    width: 80px;
    height: 4px;
    background: #eee;
    border-radius: 2px;
    overflow: hidden;
    
    .progress-fill {
      height: 100%;
      background: #667eea;
      transition: width 0.3s ease;
    }
  }
`;

const AnnouncementList = styled.div`
  display: flex;
  flex-direction: column;
  gap: 1rem;
`;

const AnnouncementItem = styled.div`
  padding: 1rem;
  border-left: 3px solid #667eea;
  background: #f8f9ff;
  border-radius: 0 6px 6px 0;
  
  .title {
    font-weight: 600;
    color: #333;
    margin-bottom: 0.5rem;
  }
  
  .content {
    font-size: 0.9rem;
    color: #666;
    margin-bottom: 0.5rem;
  }
  
  .meta {
    font-size: 0.8rem;
    color: #999;
  }
`;

const QuickActions = styled.div`
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
`;

const ActionButton = styled.button`
  padding: 1rem;
  border: none;
  border-radius: 6px;
  background: ${props => props.color || '#667eea'};
  color: white;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  }
  
  &:active {
    transform: translateY(0);
  }
`;

const StudentDashboard = () => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [dashboardData, setDashboardData] = useState(null);

  useEffect(() => {
    // Simulate API call to fetch dashboard data
    const fetchDashboardData = async () => {
      try {
        // In a real application, this would be an API call
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setDashboardData({
          stats: {
            enrolledCourses: 6,
            completedAssignments: 24,
            upcomingDeadlines: 3,
            averageGrade: 87.5
          },
          courses: [
            {
              id: 1,
              name: 'Computer Science 101',
              instructor: 'Dr. Smith',
              progress: 75,
              color: '#667eea'
            },
            {
              id: 2,
              name: 'Mathematics for CS',
              instructor: 'Prof. Johnson',
              progress: 60,
              color: '#f093fb'
            },
            {
              id: 3,
              name: 'Data Structures',
              instructor: 'Dr. Williams',
              progress: 90,
              color: '#4facfe'
            },
            {
              id: 4,
              name: 'Web Development',
              instructor: 'Ms. Davis',
              progress: 45,
              color: '#43e97b'
            }
          ],
          announcements: [
            {
              id: 1,
              title: 'Midterm Exam Schedule Released',
              content: 'Check your course pages for detailed exam schedules and preparation materials.',
              date: '2024-01-15',
              course: 'Computer Science 101'
            },
            {
              id: 2,
              title: 'New Assignment: Data Structures Project',
              content: 'Implement a binary search tree with full documentation. Due next Friday.',
              date: '2024-01-14',
              course: 'Data Structures'
            },
            {
              id: 3,
              title: 'Office Hours Extended',
              content: 'Additional office hours available this week for exam preparation.',
              date: '2024-01-13',
              course: 'Mathematics for CS'
            }
          ]
        });
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <DashboardContainer>
      <WelcomeSection>
        <h1>Welcome back, {user?.name || 'Student'}!</h1>
        <p>Here's what's happening in your courses today.</p>
      </WelcomeSection>

      <StatsGrid>
        <StatCard color="#667eea">
          <h3>Enrolled Courses</h3>
          <div className="value">{dashboardData?.stats.enrolledCourses}</div>
          <div className="change">Active this semester</div>
        </StatCard>
        
        <StatCard color="#43e97b">
          <h3>Completed Assignments</h3>
          <div className="value">{dashboardData?.stats.completedAssignments}</div>
          <div className="change">+3 this week</div>
        </StatCard>
        
        <StatCard color="#f093fb">
          <h3>Upcoming Deadlines</h3>
          <div className="value">{dashboardData?.stats.upcomingDeadlines}</div>
          <div className="change">Next 7 days</div>
        </StatCard>
        
        <StatCard color="#4facfe">
          <h3>Average Grade</h3>
          <div className="value">{dashboardData?.stats.averageGrade}%</div>
          <div className="change">+2.5% from last month</div>
        </StatCard>
      </StatsGrid>

      <ContentGrid>
        <MainContent>
          <Card>
            <CardHeader>
              <h2>My Courses</h2>
            </CardHeader>
            <CardContent>
              <CourseList>
                {dashboardData?.courses.map(course => (
                  <CourseItem key={course.id}>
                    <CourseIcon color={course.color}>
                      {course.name.split(' ').map(word => word[0]).join('').slice(0, 2)}
                    </CourseIcon>
                    <CourseInfo>
                      <h3>{course.name}</h3>
                      <p>Instructor: {course.instructor}</p>
                    </CourseInfo>
                    <CourseProgress>
                      <div className="percentage">{course.progress}%</div>
                      <div className="progress-bar">
                        <div 
                          className="progress-fill" 
                          style={{ width: `${course.progress}%` }}
                        />
                      </div>
                    </CourseProgress>
                  </CourseItem>
                ))}
              </CourseList>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <h2>Quick Actions</h2>
            </CardHeader>
            <CardContent>
              <QuickActions>
                <ActionButton color="#667eea">
                  View Assignments
                </ActionButton>
                <ActionButton color="#43e97b">
                  Check Grades
                </ActionButton>
                <ActionButton color="#f093fb">
                  Join Study Group
                </ActionButton>
                <ActionButton color="#4facfe">
                  Schedule Meeting
                </ActionButton>
              </QuickActions>
            </CardContent>
          </Card>
        </MainContent>

        <Sidebar>
          <Card>
            <CardHeader>
              <h2>Recent Announcements</h2>
            </CardHeader>
            <CardContent>
              <AnnouncementList>
                {dashboardData?.announcements.map(announcement => (
                  <AnnouncementItem key={announcement.id}>
                    <div className="title">{announcement.title}</div>
                    <div className="content">{announcement.content}</div>
                    <div className="meta">
                      {announcement.course} • {new Date(announcement.date).toLocaleDateString()}
                    </div>
                  </AnnouncementItem>
                ))}
              </AnnouncementList>
            </CardContent>
          </Card>
        </Sidebar>
      </ContentGrid>
    </DashboardContainer>
  );
};

export default StudentDashboard;