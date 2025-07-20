import React, { useState, useEffect } from 'react';
import { Helmet } from 'react-helmet';
import VideoPlayer from '../components/VideoPlayer';
import './VideoPage.css';

const VideoPage = () => {
  const [videos, setVideos] = useState([]);
  const [selectedVideo, setSelectedVideo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [uploadModalOpen, setUploadModalOpen] = useState(false);

  // Sample video data - in production, this would come from an API
  const sampleVideos = [
    {
      id: 'video-1',
      title: 'Introduction to AWS Lambda',
      description: 'Learn the basics of serverless computing with AWS Lambda functions.',
      thumbnail: '/api/videos/video-1/thumbnail.jpg',
      videoUrl: '/api/videos/video-1/stream',
      duration: 1800, // 30 minutes
      qualities: ['1080p', '720p', '480p', 'hls'],
      uploadDate: '2024-01-15',
      instructor: 'Dr. Sarah Johnson',
      views: 1250,
      course: 'AWS Fundamentals'
    },
    {
      id: 'video-2', 
      title: 'Building Scalable APIs with API Gateway',
      description: 'Deep dive into creating RESTful APIs using AWS API Gateway with Lambda integration.',
      thumbnail: '/api/videos/video-2/thumbnail.jpg',
      videoUrl: '/api/videos/video-2/stream',
      duration: 2700, // 45 minutes
      qualities: ['1080p', '720p', '480p'],
      uploadDate: '2024-01-20',
      instructor: 'Prof. Michael Chen',
      views: 980,
      course: 'Advanced AWS Services'
    },
    {
      id: 'video-3',
      title: 'Database Design with DynamoDB',
      description: 'Master NoSQL database design patterns and best practices with Amazon DynamoDB.',
      thumbnail: '/api/videos/video-3/thumbnail.jpg',
      videoUrl: '/api/videos/video-3/stream',
      duration: 3600, // 60 minutes
      qualities: ['1080p', '720p', '480p', 'hls'],
      uploadDate: '2024-01-25',
      instructor: 'Dr. Sarah Johnson',
      views: 1500,
      course: 'Database Systems'
    }
  ];

  useEffect(() => {
    // Simulate API call to fetch videos
    const fetchVideos = async () => {
      try {
        setLoading(true);
        // In production: const response = await fetch('/api/videos');
        // const videoData = await response.json();
        
        // Simulate network delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setVideos(sampleVideos);
        if (sampleVideos.length > 0) {
          setSelectedVideo(sampleVideos[0]);
        }
      } catch (err) {
        setError('Failed to load videos. Please try again later.');
        console.error('Error fetching videos:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchVideos();
  }, []);

  const handleVideoSelect = (video) => {
    setSelectedVideo(video);
  };

  const handleVideoProgress = (progressData) => {
    // Save progress to backend
    console.log('Video progress:', progressData);
    // fetch(`/api/videos/${selectedVideo.id}/progress`, {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(progressData)
    // });
  };

  const handleVideoComplete = (completionData) => {
    // Mark video as completed
    console.log('Video completed:', completionData);
    // fetch(`/api/videos/${selectedVideo.id}/complete`, {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(completionData)
    // });
  };

  const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  if (loading) {
    return (
      <div className="video-page loading">
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading video lectures...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="video-page error">
        <div className="error-container">
          <h2>Error Loading Videos</h2>
          <p>{error}</p>
          <button 
            onClick={() => window.location.reload()} 
            className="retry-button"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <>
      <Helmet>
        <title>Video Lectures - AWS Education Platform</title>
        <meta name="description" content="Access comprehensive video lectures on AWS services and cloud computing concepts." />
      </Helmet>
      
      <div className="video-page">
        <div className="video-page-header">
          <h1>Video Lectures</h1>
          <p>Learn AWS services through comprehensive video tutorials</p>
          <button 
            className="upload-button"
            onClick={() => setUploadModalOpen(true)}
          >
            📹 Upload Video
          </button>
        </div>

        <div className="video-content">
          {/* Main Video Player */}
          <div className="video-player-section">
            {selectedVideo ? (
              <div className="selected-video">
                <VideoPlayer
                  videoId={selectedVideo.id}
                  videoUrl={selectedVideo.videoUrl}
                  title={selectedVideo.title}
                  description={selectedVideo.description}
                  thumbnail={selectedVideo.thumbnail}
                  qualities={selectedVideo.qualities}
                  defaultQuality="720p"
                  enableAnalytics={true}
                  onProgress={handleVideoProgress}
                  onComplete={handleVideoComplete}
                  controls={true}
                  className="main-video-player"
                />
                
                <div className="video-info">
                  <div className="video-meta">
                    <h2>{selectedVideo.title}</h2>
                    <div className="video-stats">
                      <span className="duration">{formatDuration(selectedVideo.duration)}</span>
                      <span className="views">{selectedVideo.views.toLocaleString()} views</span>
                      <span className="upload-date">
                        Uploaded {new Date(selectedVideo.uploadDate).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="instructor-info">
                      <span className="instructor">By {selectedVideo.instructor}</span>
                      <span className="course">{selectedVideo.course}</span>
                    </div>
                  </div>
                  <p className="video-description">{selectedVideo.description}</p>
                </div>
              </div>
            ) : (
              <div className="no-video-selected">
                <h3>Select a video to start learning</h3>
                <p>Choose from the video library on the right to begin watching.</p>
              </div>
            )}
          </div>

          {/* Video Library Sidebar */}
          <div className="video-library">
            <h3>Video Library</h3>
            <div className="video-list">
              {videos.map((video) => (
                <div
                  key={video.id}
                  className={`video-item ${selectedVideo?.id === video.id ? 'active' : ''}`}
                  onClick={() => handleVideoSelect(video)}
                >
                  <div className="video-thumbnail">
                    <img src={video.thumbnail} alt={video.title} />
                    <div className="video-duration">{formatDuration(video.duration)}</div>
                  </div>
                  <div className="video-item-info">
                    <h4>{video.title}</h4>
                    <p className="video-instructor">{video.instructor}</p>
                    <p className="video-course">{video.course}</p>
                    <div className="video-item-stats">
                      <span>{video.views.toLocaleString()} views</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Upload Modal */}
        {uploadModalOpen && (
          <VideoUploadModal 
            onClose={() => setUploadModalOpen(false)}
            onUploadComplete={(newVideo) => {
              setVideos([...videos, newVideo]);
              setUploadModalOpen(false);
            }}
          />
        )}
      </div>
    </>
  );
};

// Video Upload Modal Component
const VideoUploadModal = ({ onClose, onUploadComplete }) => {
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [dragOver, setDragOver] = useState(false);

  const handleFileUpload = async (file) => {
    if (!file) return;

    try {
      setUploading(true);
      
      // Get presigned URL from Lambda function
      const presignedResponse = await fetch('/api/video/upload-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'generateUploadUrl',
          fileName: file.name,
          fileSize: file.size,
          contentType: file.type,
          userId: 'current-user-id', // Get from auth context
          courseId: 'current-course-id'
        })
      });

      const presignedData = await presignedResponse.json();
      
      if (!presignedData.success) {
        throw new Error(presignedData.error);
      }

      // Upload file to S3
      if (presignedData.data.uploadType === 'single') {
        await uploadSingleFile(file, presignedData.data);
      } else {
        await uploadMultipartFile(file, presignedData.data);
      }

      // Notify parent component
      const newVideo = {
        id: `video-${Date.now()}`,
        title: file.name.replace(/\.[^/.]+$/, ''),
        description: 'Newly uploaded video',
        thumbnail: '/default-thumbnail.jpg',
        videoUrl: `/api/videos/${presignedData.data.fileKey}/stream`,
        duration: 0, // Will be updated after processing
        qualities: ['processing'],
        uploadDate: new Date().toISOString().split('T')[0],
        instructor: 'You',
        views: 0,
        course: 'Your Uploads'
      };

      onUploadComplete(newVideo);

    } catch (error) {
      console.error('Upload failed:', error);
      alert(`Upload failed: ${error.message}`);
    } finally {
      setUploading(false);
      setUploadProgress(0);
    }
  };

  const uploadSingleFile = async (file, uploadData) => {
    const formData = new FormData();
    Object.keys(uploadData.fields).forEach(key => {
      formData.append(key, uploadData.fields[key]);
    });
    formData.append('file', file);

    const xhr = new XMLHttpRequest();
    
    return new Promise((resolve, reject) => {
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const progress = (e.loaded / e.total) * 100;
          setUploadProgress(progress);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status === 204) {
          resolve();
        } else {
          reject(new Error(`Upload failed with status ${xhr.status}`));
        }
      });

      xhr.addEventListener('error', () => {
        reject(new Error('Upload failed'));
      });

      xhr.open('POST', uploadData.uploadUrl);
      xhr.send(formData);
    });
  };

  const uploadMultipartFile = async (file, uploadData) => {
    // Implement multipart upload for large files
    // This is a simplified version - in production, you'd want more robust error handling
    const parts = [];
    
    for (let i = 0; i < uploadData.partUrls.length; i++) {
      const partUrl = uploadData.partUrls[i];
      const start = i * uploadData.partSize;
      const end = Math.min(start + uploadData.partSize, file.size);
      const partData = file.slice(start, end);

      const response = await fetch(partUrl.uploadUrl, {
        method: 'PUT',
        body: partData
      });

      if (!response.ok) {
        throw new Error(`Failed to upload part ${i + 1}`);
      }

      const etag = response.headers.get('ETag');
      parts.push({
        partNumber: partUrl.partNumber,
        etag: etag
      });

      setUploadProgress(((i + 1) / uploadData.partUrls.length) * 100);
    }

    // Complete multipart upload
    await fetch('/api/video/upload-url', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'completeMultipartUpload',
        fileKey: uploadData.fileKey,
        uploadId: uploadData.uploadId,
        parts: parts
      })
    });
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    
    const files = Array.from(e.dataTransfer.files);
    const videoFile = files.find(file => file.type.startsWith('video/'));
    
    if (videoFile) {
      handleFileUpload(videoFile);
    } else {
      alert('Please select a valid video file.');
    }
  };

  const handleFileInput = (e) => {
    const file = e.target.files[0];
    if (file) {
      handleFileUpload(file);
    }
  };

  return (
    <div className="upload-modal-overlay" onClick={onClose}>
      <div className="upload-modal" onClick={e => e.stopPropagation()}>
        <div className="upload-modal-header">
          <h3>Upload Video Lecture</h3>
          <button className="close-button" onClick={onClose}>×</button>
        </div>
        
        <div className="upload-modal-content">
          {!uploading ? (
            <div
              className={`upload-area ${dragOver ? 'drag-over' : ''}`}
              onDrop={handleDrop}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
            >
              <div className="upload-icon">📹</div>
              <h4>Drag and drop your video here</h4>
              <p>or</p>
              <label className="file-input-label">
                <input
                  type="file"
                  accept="video/*"
                  onChange={handleFileInput}
                  style={{ display: 'none' }}
                />
                Choose File
              </label>
              <p className="upload-info">
                Supported formats: MP4, MOV, AVI, MKV, WebM<br/>
                Maximum file size: 5GB
              </p>
            </div>
          ) : (
            <div className="upload-progress">
              <h4>Uploading Video...</h4>
              <div className="progress-bar">
                <div 
                  className="progress-fill" 
                  style={{ width: `${uploadProgress}%` }}
                ></div>
              </div>
              <p>{Math.round(uploadProgress)}% complete</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default VideoPage;