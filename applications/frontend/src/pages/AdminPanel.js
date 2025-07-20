import React, { useState, useEffect } from 'react';
import styled from 'styled-components';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';

const AdminContainer = styled.div`
  max-width: 1600px;
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
  
  h1 {
    margin: 0 0 0.5rem 0;
    font-size: 2.5rem;
  }
  
  p {
    margin: 0;
    opacity: 0.9;
    font-size: 1.1rem;
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

const MetricsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
`;

const MetricCard = styled.div`
  background: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  border-left: 4px solid ${props => props.color || '#667eea'};
  
  .metric-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    
    h3 {
      margin: 0;
      color: #333;
      font-size: 0.9rem;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .trend {
      font-size: 0.8rem;
      padding: 0.25rem 0.5rem;
      border-radius: 12px;
      background: ${props => props.trend === 'up' ? '#e8f5e8' : props.trend === 'down' ? '#ffeaea' : '#f0f0f0'};
      color: ${props => props.trend === 'up' ? '#2d7d2d' : props.trend === 'down' ? '#d63031' : '#666'};
    }
  }
  
  .value {
    font-size: 2.5rem;
    font-weight: bold;
    color: ${props => props.color || '#667eea'};
    margin-bottom: 0.5rem;
  }
  
  .description {
    font-size: 0.85rem;
    color: #666;
  }
`;

const ContentGrid = styled.div`
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 2rem;
  
  @media (max-width: 1200px) {
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
  justify-content: between;
  align-items: center;
  
  h2 {
    margin: 0;
    font-size: 1.2rem;
    color: #333;
  }
  
  .actions {
    display: flex;
    gap: 0.5rem;
  }
`;

const CardContent = styled.div`
  padding: 1.5rem;
`;

const ActionButton = styled.button`
  padding: 0.5rem 1rem;
  border: 1px solid ${props => props.primary ? '#667eea' : '#ddd'};
  border-radius: 4px;
  background: ${props => props.primary ? '#667eea' : 'white'};
  color: ${props => props.primary ? 'white' : '#666'};
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    background: ${props => props.primary ? '#5a6fd8' : '#f8f9ff'};
    border-color: #667eea;
    color: ${props => props.primary ? 'white' : '#667eea'};
  }
`;

const UserTable = styled.div`
  .table-header {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr 1fr;
    gap: 1rem;
    padding: 1rem;
    background: #f8f9fa;
    font-weight: 600;
    color: #333;
    font-size: 0.9rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  
  .table-row {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr 1fr;
    gap: 1rem;
    padding: 1rem;
    border-bottom: 1px solid #eee;
    align-items: center;
    transition: background 0.2s ease;
    
    &:hover {
      background: #f8f9ff;
    }
  }
`;

const UserInfo = styled.div`
  display: flex;
  align-items: center;
  gap: 0.75rem;
  
  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: ${props => props.color || '#667eea'};
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-weight: bold;
  }
  
  .info {
    .name {
      font-weight: 600;
      color: #333;
      margin-bottom: 0.25rem;
    }
    
    .email {
      font-size: 0.8rem;
      color: #666;
    }
  }
`;

const StatusBadge = styled.span`
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: 600;
  background: ${props => {
    switch (props.status) {
      case 'active': return '#e8f5e8';
      case 'inactive': return '#ffeaea';
      case 'pending': return '#fff3cd';
      default: return '#f0f0f0';
    }
  }};
  color: ${props => {
    switch (props.status) {
      case 'active': return '#2d7d2d';
      case 'inactive': return '#d63031';
      case 'pending': return '#856404';
      default: return '#666';
    }
  }};
`;

const SystemHealth = styled.div`
  display: flex;
  flex-direction: column;
  gap: 1rem;
`;

const HealthItem = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  border: 1px solid #eee;
  border-radius: 6px;
  
  .service {
    .name {
      font-weight: 600;
      color: #333;
      margin-bottom: 0.25rem;
    }
    
    .description {
      font-size: 0.8rem;
      color: #666;
    }
  }
  
  .status {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    
    .indicator {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: ${props => {
        switch (props.status) {
          case 'healthy': return '#43e97b';
          case 'warning': return '#f093fb';
          case 'error': return '#ff6b6b';
          default: return '#ccc';
        }
      }};
    }
    
    .text {
      font-size: 0.8rem;
      font-weight: 600;
      color: ${props => {
        switch (props.status) {
          case 'healthy': return '#2d7d2d';
          case 'warning': return '#856404';
          case 'error': return '#d63031';
          default: return '#666';
        }
      }};
    }
  }
`;

const AdminPanel = () => {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [adminData, setAdminData] = useState(null);

  useEffect(() => {
    // Simulate API call to fetch admin data
    const fetchAdminData = async () => {
      try {
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setAdminData({
          metrics: {
            totalUsers: 1247,
            activeUsers: 892,
            totalCourses: 45,
            systemUptime: 99.8,
            storageUsed: 2.4,
            monthlyActiveUsers: 756
          },
          users: [
            {
              id: 1,
              name: 'Dr. Sarah Johnson',
              email: 'sarah.johnson@university.edu',
              role: 'Teacher',
              status: 'active',
              lastLogin: '2024-01-15',
              courses: 3
            },
            {
              id: 2,
              name: 'Michael Chen',
              email: 'michael.chen@university.edu',
              role: 'Student',
              status: 'active',
              lastLogin: '2024-01-15',
              courses: 6
            },
            {
              id: 3,
              name: 'Prof. Robert Davis',
              email: 'robert.davis@university.edu',
              role: 'Teacher',
              status: 'inactive',
              lastLogin: '2024-01-10',
              courses: 2
            },
            {
              id: 4,
              name: 'Emily Rodriguez',
              email: 'emily.rodriguez@university.edu',
              role: 'Student',
              status: 'pending',
              lastLogin: 'Never',
              courses: 0
            }
          ],
          systemHealth: [
            {
              name: 'API Gateway',
              description: 'Authentication and API services',
              status: 'healthy'
            },
            {
              name: 'Database',
              description: 'PostgreSQL cluster',
              status: 'healthy'
            },
            {
              name: 'File Storage',
              description: 'S3 and CloudFront CDN',
              status: 'healthy'
            },
            {
              name: 'Chat System',
              description: 'Real-time messaging',
              status: 'warning'
            },
            {
              name: 'Video Platform',
              description: 'Video streaming and processing',
              status: 'healthy'
            },
            {
              name: 'Monitoring',
              description: 'CloudWatch and alerting',
              status: 'healthy'
            }
          ]
        });
      } catch (error) {
        console.error('Error fetching admin data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchAdminData();
  }, []);

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <AdminContainer>
      <HeaderSection>
        <h1>Admin Panel</h1>
        <p>System administration and user management for the AWS Education Platform</p>
      </HeaderSection>

      <TabNavigation>
        <Tab 
          active={activeTab === 'dashboard'} 
          onClick={() => setActiveTab('dashboard')}
        >
          Dashboard
        </Tab>
        <Tab 
          active={activeTab === 'users'} 
          onClick={() => setActiveTab('users')}
        >
          User Management
        </Tab>
        <Tab 
          active={activeTab === 'courses'} 
          onClick={() => setActiveTab('courses')}
        >
          Course Management
        </Tab>
        <Tab 
          active={activeTab === 'system'} 
          onClick={() => setActiveTab('system')}
        >
          System Health
        </Tab>
        <Tab 
          active={activeTab === 'analytics'} 
          onClick={() => setActiveTab('analytics')}
        >
          Analytics
        </Tab>
        <Tab 
          active={activeTab === 'settings'} 
          onClick={() => setActiveTab('settings')}
        >
          Settings
        </Tab>
      </TabNavigation>

      <TabContent active={activeTab === 'dashboard'}>
        <MetricsGrid>
          <MetricCard color="#667eea" trend="up">
            <div className="metric-header">
              <h3>Total Users</h3>
              <span className="trend">↗ +12%</span>
            </div>
            <div className="value">{adminData?.metrics.totalUsers.toLocaleString()}</div>
            <div className="description">Registered students and teachers</div>
          </MetricCard>
          
          <MetricCard color="#43e97b" trend="up">
            <div className="metric-header">
              <h3>Active Users</h3>
              <span className="trend">↗ +8%</span>
            </div>
            <div className="value">{adminData?.metrics.activeUsers.toLocaleString()}</div>
            <div className="description">Users active in last 30 days</div>
          </MetricCard>
          
          <MetricCard color="#f093fb" trend="stable">
            <div className="metric-header">
              <h3>Total Courses</h3>
              <span className="trend">→ 0%</span>
            </div>
            <div className="value">{adminData?.metrics.totalCourses}</div>
            <div className="description">Active courses this semester</div>
          </MetricCard>
          
          <MetricCard color="#4facfe" trend="up">
            <div className="metric-header">
              <h3>System Uptime</h3>
              <span className="trend">↗ +0.2%</span>
            </div>
            <div className="value">{adminData?.metrics.systemUptime}%</div>
            <div className="description">Last 30 days availability</div>
          </MetricCard>
          
          <MetricCard color="#ff6b6b" trend="up">
            <div className="metric-header">
              <h3>Storage Used</h3>
              <span className="trend">↗ +15%</span>
            </div>
            <div className="value">{adminData?.metrics.storageUsed} TB</div>
            <div className="description">Total platform storage</div>
          </MetricCard>
          
          <MetricCard color="#feca57" trend="up">
            <div className="metric-header">
              <h3>Monthly Active</h3>
              <span className="trend">↗ +5%</span>
            </div>
            <div className="value">{adminData?.metrics.monthlyActiveUsers.toLocaleString()}</div>
            <div className="description">Unique users this month</div>
          </MetricCard>
        </MetricsGrid>

        <ContentGrid>
          <Card>
            <CardHeader>
              <h2>Recent Activity</h2>
              <div className="actions">
                <ActionButton>View All</ActionButton>
              </div>
            </CardHeader>
            <CardContent>
              <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
                Recent system activities, user registrations, and course creations will appear here.
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <h2>System Health</h2>
              <div className="actions">
                <ActionButton primary>Refresh</ActionButton>
              </div>
            </CardHeader>
            <CardContent>
              <SystemHealth>
                {adminData?.systemHealth.map((service, index) => (
                  <HealthItem key={index} status={service.status}>
                    <div className="service">
                      <div className="name">{service.name}</div>
                      <div className="description">{service.description}</div>
                    </div>
                    <div className="status">
                      <div className="indicator"></div>
                      <div className="text">
                        {service.status === 'healthy' ? 'Healthy' : 
                         service.status === 'warning' ? 'Warning' : 'Error'}
                      </div>
                    </div>
                  </HealthItem>
                ))}
              </SystemHealth>
            </CardContent>
          </Card>
        </ContentGrid>
      </TabContent>

      <TabContent active={activeTab === 'users'}>
        <Card>
          <CardHeader>
            <h2>User Management</h2>
            <div className="actions">
              <ActionButton>Export Users</ActionButton>
              <ActionButton primary>Add User</ActionButton>
            </div>
          </CardHeader>
          <CardContent>
            <UserTable>
              <div className="table-header">
                <div>User</div>
                <div>Role</div>
                <div>Status</div>
                <div>Last Login</div>
                <div>Actions</div>
              </div>
              {adminData?.users.map(user => (
                <div key={user.id} className="table-row">
                  <UserInfo color={user.role === 'Teacher' ? '#667eea' : '#43e97b'}>
                    <div className="avatar">
                      {user.name.split(' ').map(n => n[0]).join('')}
                    </div>
                    <div className="info">
                      <div className="name">{user.name}</div>
                      <div className="email">{user.email}</div>
                    </div>
                  </UserInfo>
                  <div>{user.role}</div>
                  <StatusBadge status={user.status}>
                    {user.status.charAt(0).toUpperCase() + user.status.slice(1)}
                  </StatusBadge>
                  <div>{user.lastLogin}</div>
                  <div>
                    <ActionButton style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}>
                      Edit
                    </ActionButton>
                  </div>
                </div>
              ))}
            </UserTable>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'courses'}>
        <Card>
          <CardHeader>
            <h2>Course Management</h2>
            <div className="actions">
              <ActionButton>Import Courses</ActionButton>
              <ActionButton primary>Create Course</ActionButton>
            </div>
          </CardHeader>
          <CardContent>
            <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
              Course management interface will be implemented here.
              Features will include course creation, enrollment management, and analytics.
            </div>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'system'}>
        <Card>
          <CardHeader>
            <h2>System Health Monitoring</h2>
            <div className="actions">
              <ActionButton>View Logs</ActionButton>
              <ActionButton primary>Run Diagnostics</ActionButton>
            </div>
          </CardHeader>
          <CardContent>
            <SystemHealth>
              {adminData?.systemHealth.map((service, index) => (
                <HealthItem key={index} status={service.status}>
                  <div className="service">
                    <div className="name">{service.name}</div>
                    <div className="description">{service.description}</div>
                  </div>
                  <div className="status">
                    <div className="indicator"></div>
                    <div className="text">
                      {service.status === 'healthy' ? 'Healthy' : 
                       service.status === 'warning' ? 'Warning' : 'Error'}
                    </div>
                  </div>
                </HealthItem>
              ))}
            </SystemHealth>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'analytics'}>
        <Card>
          <CardHeader>
            <h2>Platform Analytics</h2>
            <div className="actions">
              <ActionButton>Export Report</ActionButton>
              <ActionButton primary>Generate Report</ActionButton>
            </div>
          </CardHeader>
          <CardContent>
            <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
              Analytics dashboard will show platform usage statistics,
              user engagement metrics, and performance insights.
            </div>
          </CardContent>
        </Card>
      </TabContent>

      <TabContent active={activeTab === 'settings'}>
        <Card>
          <CardHeader>
            <h2>System Settings</h2>
            <div className="actions">
              <ActionButton primary>Save Changes</ActionButton>
            </div>
          </CardHeader>
          <CardContent>
            <div style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
              System configuration settings will be available here.
              Including email settings, security policies, and feature toggles.
            </div>
          </CardContent>
        </Card>
      </TabContent>
    </AdminContainer>
  );
};

export default AdminPanel;