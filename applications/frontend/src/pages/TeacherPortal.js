import React, { useState, useEffect } from 'react';
import styled from 'styled-components';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';

const PortalContainer = styled.div`
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
  
  @media (max-width: 768px) {
    padding: 1rem;
  }
`;

const HeaderSection = styled.div`
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  border-radius: 12px;
  margin-bottom: 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  
  @media (max-width: 768px) {
    flex-direction: column;
    text-align: center;
    gap: 1rem;
  }
  
  .header-content {
    h1 {
      margin: 0 0 0.5rem 0;
      font-size: 2rem;
    }
    
    p {
      margin: 0;
      opacity: 0.9;
    }
  }
  
  .header-actions {
    display: flex;
    gap: 1rem;
    
    @media (max-width: 768px) {
      width: 100%;
      justify-content: center;
    }
  }
`;

const ActionButton = styled.button`
  padding: 0.75rem 1.5rem;
  border: 2px solid white;
  border-radius: 6px;
  background: ${props => props.primary ? 'white' : 'transparent'};
  color: ${props => props.primary ? '#667eea' : 'white'};
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    background: white;
    color: #667eea;
    transform: translateY(-2px);
  }
`;

const TabNavigation = styled.div`
  display: flex;
  border-bottom: 2px solid #eee;
  margin-bottom: 2rem;
  overflow-x: auto;
`;

const Tab = styled.button`
  padding: 1rem 2rem;
  border: none;
  background: none;
  font-weight: 600;
  color: ${props => props.active ? '#667eea' : '#666'};
  border-bottom: 2px solid ${props => props.active ? '#667eea' : 'transparent'};
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
  
  &:hover {
    color: #667eea;
  }
`;

const TabContent = styled.div`
  display: ${props => props.active ? 'block' : 'none'};
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
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
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  
  @media (max-width: 968px) {
    grid-template-columns: 1fr;
  }
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
  display: flex;
  justify-content: space-between;
  align-items: center;
  
  h2 {
    margin: 0;
    font-size: 1.2rem;
    color: #333;
  }
`;

const CardContent = styled.div`
  padding: 1.5rem;
`;

const CourseGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
`;

const CourseCard = styled.div`
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: all 0.2s ease;
  
  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
  }
`;

const CourseHeader = styled.div`
  background: ${props => props.color || '#667eea'};
  color: white;
  padding: 1.5rem;
  
  h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.2rem;
  }
  
  p {
    margin: 0;
    opacity: 0.9;
    font-size: 0.9rem;
  }
`;

const CourseStats = styled.div`
  padding: 1rem 1.5rem;
  display: flex;
  justify-content: space-between;
  border-bottom: 1px solid #eee;
  
  .stat {
    text-align: center;
    
    .value {
      font-size: 1.5rem;
      font-weight: bold;
      color: #333;
    }
    
    .label {
      font-size: 0.8rem;
      color: #666;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
  }
`;

const CourseActions = styled.div`
  padding: 1rem 1.5rem;
  display: flex;
  gap: 0.5rem;
`;

const SmallButton = styled.button`
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  color: #666;
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    border-color: #667eea;
    color: #667eea;
  }
  
  &.primary {
    background: #667eea;
    color: white;
    border-color: #667eea;
    
    &:hover {
      background: #5a6fd8;
    }
  }
`;

const StudentList = styled.div`
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-height: 300px;
  overflow-y: auto;
`;

const StudentItem = styled.div`
  display: flex;
  align-items: center;
  padding: 0.75rem;
  border: 1px solid #eee;
  border-radius: 6px;
  transition: all 0.2s ease;
  
  &:hover {
    border-color: #667eea;
    background: #f8f9ff;
  }
`;

const StudentAvatar = styled.div`
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: ${props => props.color || '#667eea'};
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  margin-right: 1rem;
`;

const StudentInfo = styled.div`
  flex: 1;
  
  .name {
    font-weight: 600;
    color: #333;
    margin-bottom: 0.25rem;
  }
  
  .email {
    font-size: 0.8rem;
    color: #666;
  }
`;

const StudentGrade = styled.div`
  text-align: right;
  
  .grade {
    font-weight: bold;
    color: ${props => {
      const grade = parseFloat(props.grade);
      if (grade >= 90) return '#43e97b';
      if (grade >= 80) return '#4facfe';
      if (grade >= 70) return '#f093fb';
      return '#ff6b6b';
    }};
    font-size: 1.1rem;
  }
  
  .status {
    font-size: 0.8rem;
    color: #666;
  }
`;

const TeacherPortal = () => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('overview');
  const [portalData, setPortalData] = useState(null);

  useEffect(() => {
    // Simulate API call to fetch teacher portal data
    const fetchPortalData = async () => {
      try {
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setPortalData({
          stats: {
            totalStudents: 156,
            activeCourses: 4,
            pendingGrades: 23,
            averageAttendance: 92.5
          },
          courses: [
            {
              id: 1,
              name: 'Computer Science 101',
              code: 'CS101',
              semester: 'Spring 2024',
              students: 45,
              assignments: 8,
              avgGrade: 87.2,
              color: '#667eea'
            },
            {
              id: 2,
              name: 'Advanced Programming',
              code: 'CS301',
              semester: 'Spring 2024',
              students: 32,
              assignments: 6,
              avgGrade: 91.5,
              color: '#43e97b'
            },
            {
              id: 3,
              name: 'Database Systems',
              code: 'CS205',
              semester: 'Spring 2024',
              students: 38,
              assignments: 7,
              avgGrade: 84.8,
              color: '#f093fb'
            },
            {
              id: 4,
              name: 'Software Engineering',
              code: 'CS401',
              semester: 'Spring 2024',
              students: 41,
              assignments: 9,
              avgGrade: 89.3,
              color: '#4facfe'
            }
          ],
          recentStudents: [
            {
              id: 1,
              name: 'Alice Johnson',
              email: 'alice.johnson@university.edu',
              grade: 94.5,
              status: 'Excellent',
              color: '#667eea'
            },
            {
              id: 2,
              name: 'Bob Smith',
              email: 'bob.smith@university.edu',
              grade: 87.2,
              status: 'Good',
              color: '#43e97b'
            },
            {
              id: 3,
              name: 'Carol Davis',
              email: 'carol.davis@university.edu',
              grade: 91.8,
              status: 'Excellent',
              color: '#f093fb'
            },
            {
              id: 4,
              name: 'David Wilson',
              email: 'david.wilson@university.edu',
              grade: 78.5,
              status: 'Needs Help',
              color: '#4facfe'
            }
          ]
        });
      } catch (error) {
        console.error('Error fetching portal data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchPortalData();
  }, []);

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <PortalContainer>
      <HeaderSection>
        <div className="header-content">
          <h1>Teacher Portal</h1>
          <p>Welcome back, {user?.name || 'Professor'}! Manage your courses and track student progress.</p>
        </div>
        <div className="header-actions">
          <ActionButton>Create Assignment</ActionButton>
          <ActionButton primary>New Course</ActionButton>
        </div>
      </HeaderSection>

      <TabNavigation>
        <Tab 
          active={activeTab === 'overview'} 
          onClick={() => setActiveTab('overview')}
        >
          Overview
        </Tab>
        <Tab 
          active={activeTab === 'courses'} 
          onClick={() => setActiveTab('courses')}
        >
          My Courses
        </Tab>
        <Tab 
          active={activeTab === 'students'} 
          onClick={() => setActiveTab('students')}
        >
          Students
        </Tab>
        <Tab 
          active={activeTab === 'grades'} 
          onClick={() => setActiveTab('grades')}
        >
          Grades
        </Tab>
        <Tab 
          active={activeTab === 'analytics'} 
          onClick={() => setActiveTab('analytics')}
        >
          Analytics
        </Tab>
      </TabNavigation>

      <TabContent active={activeTab === 'overview'}>
        <StatsGrid>
          <StatCard color="#667eea">
            <h3>Total Students</h3>
            <div className="value">{portalData?.stats.totalStudents}</div>
            <div className="change">Across all courses</div>
          </StatCard>
          
          <StatCard color="#43e97b">
            <h3>Active Courses</h3>
            <div className="value">{portalData?.stats.activeCourses}</div>
            <div className="change">This semester</div>
          </StatCard>
          
          <StatCard color="#f093fb">
            <h3>Pending Grades</h3>
            <div className="value">{portalData?.stats.pendingGrades}</div>
            <div className="change">Assignments to grade</div>
          </StatCard>
          
          <StatCard color="#4facfe">
            <h3>Avg Attendance</h3>
            <div className="value">{portalData?.stats.averageAttendance}%</div>
            <div className="change">+3.2% from last month</div>
          </StatCard>
        </StatsGrid>

        <ContentGrid>
          <Card>
            <CardHeader>
              <h2>Recent Activity</h2>
              <SmallButton>View All</SmallButton>
            </CardHeader>
            <CardContent>
              <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
                Recent assignments, submissions, and student interactions will appear here.
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <h2>Top Performing Students</h2>
              <SmallButton>View All</SmallButton>
            </CardHeader>
            <CardContent>
              <StudentList>
                {portalData?.recentStudents.map(student => (
                  <StudentItem key={student.id}>
                    <StudentAvatar color={student.color}>
                      {student.name.split(' ').map(n => n[0]).join('')}
                    </StudentAvatar>
                    <StudentInfo>
                      <div className="name">{student.name}</div>
                      <div className="email">{student.email}</div>
                    </StudentInfo>
                    <StudentGrade grade={student.grade}>
                      <div className="grade">{student.grade}%</div>
                      <div className="status">{student.status}</div>
                    </StudentGrade>
                  </StudentItem>
                ))}
              </StudentList>
            </CardContent>
          </Card>
        </ContentGrid>
      </TabContent>

      <TabContent active={activeTab === 'courses'}>
        <CourseGrid>
          {portalData?.courses.map(course => (
            <CourseCard key={course.id}>
              <CourseHeader color={course.color}>
                <h3>{course.name}</h3>
                <p>{course.code} • {course.semester}</p>
              </CourseHeader>
              <CourseStats>
                <div className="stat">
                  <div className="value">{course.students}</div>
                  <div className="label">Students</div>
                </div>
                <div className="stat">
                  <div className="value">{course.assignments}</div>
                  <div className="label">Assignments</div>
                </div>
                <div className="stat">
                  <div className="value">{course.avgGrade}%</div>
                  <div className="label">Avg Grade</div>
                </div>
              </CourseStats>
              <CourseActions>
                <SmallButton className="primary">Manage</SmallButton>
                <SmallButton>View Students</SmallButton>
                <SmallButton>Analytics</SmallButton>
              </CourseActions>
            </CourseCard>
          ))}
        </CourseGrid>
      </TabContent>

      <TabContent active={activeTab === 'students'}>
        <Card>
          <CardHeader>
            <h2>All Students</h2>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <SmallButton>Export</SmallButton>
              <SmallButton className="primary">Add Student</SmallButton>
            </div>
          </CardHeader>
          <CardContent>
            <StudentList>
              {portalData?.recentStudents.map(student => (
                <StudentItem key={student.id}>
                  <StudentAvatar color={student.color}>
                    {student.name.split(' ').map(n => n[0]).join('')}
                  </StudentAvatar>
                  <StudentInfo>
                    <div className="name">{student.name}</div>
                    <div className="email">{student.email}</div>
                  </StudentInfo>
                  <StudentGrade grade={student.grade}>
                    <div className="grade">{student.grade}%</div>
                    <div className="status">{student.status}</div>
                  </StudentGrade>
                </StudentItem>
              ))}
            </StudentList>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'grades'}>
        <Card>
          <CardHeader>
            <h2>Grade Management</h2>
            <SmallButton className="primary">Grade Assignment</SmallButton>
          </CardHeader>
          <CardContent>
            <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
              Grade management interface will be implemented here.
              Features will include bulk grading, rubrics, and grade analytics.
            </div>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'analytics'}>
        <Card>
          <CardHeader>
            <h2>Course Analytics</h2>
            <SmallButton>Export Report</SmallButton>
          </CardHeader>
          <CardContent>
            <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
              Analytics dashboard will show student performance trends,
              attendance patterns, and course effectiveness metrics.
            </div>
          </CardContent>
        </Card>
      </TabContent>
    </PortalContainer>
  );
};

export default TeacherPortal;