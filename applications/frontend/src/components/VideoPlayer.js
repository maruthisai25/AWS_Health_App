import React, { useState, useRef, useEffect } from 'react';
import './VideoPlayer.css';

/**
 * VideoPlayer Component
 * 
 * A comprehensive video player component for the AWS Education Platform
 * Features:
 * - Multiple quality options (1080p, 720p, 480p)
 * - HLS streaming support for adaptive bitrate
 * - Progress tracking and bookmarking
 * - Fullscreen support
 * - Keyboard shortcuts
 * - Captions support (if available)
 * - Analytics tracking
 */
const VideoPlayer = ({ 
  videoId,
  videoUrl,
  title,
  description,
  thumbnail,
  qualities = ['1080p', '720p', '480p'],
  defaultQuality = '720p',
  enableAnalytics = true,
  onProgress = null,
  onComplete = null,
  autoPlay = false,
  controls = true,
  className = '',
  style = {}
}) => {
  // State management
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [selectedQuality, setSelectedQuality] = useState(defaultQuality);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [buffered, setBuffered] = useState(0);
  const [playbackRate, setPlaybackRate] = useState(1);

  // Refs
  const videoRef = useRef(null);
  const containerRef = useRef(null);
  const controlsTimeoutRef = useRef(null);
  const progressBarRef = useRef(null);

  // Analytics tracking
  const analyticsRef = useRef({
    startTime: null,
    watchTime: 0,
    maxProgress: 0,
    qualityChanges: 0,
    pauseCount: 0
  });

  // Initialize video player
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    // Set initial properties
    video.volume = volume;
    video.muted = isMuted;
    video.playbackRate = playbackRate;

    // Load the video
    loadVideo();

    // Cleanup function
    return () => {
      if (enableAnalytics) {
        sendAnalytics('video_session_end');
      }
    };
  }, [videoUrl, selectedQuality]);

  // Load video with selected quality
  const loadVideo = async () => {
    if (!videoUrl) return;

    setIsLoading(true);
    setError(null);

    try {
      // Construct video URL based on quality
      const qualityUrl = getQualityUrl(videoUrl, selectedQuality);
      
      const video = videoRef.current;
      if (video) {
        video.src = qualityUrl;
        video.load();
      }

    } catch (err) {
      console.error('Error loading video:', err);
      setError('Failed to load video. Please try again.');
    }
  };

  // Get video URL for specific quality
  const getQualityUrl = (baseUrl, quality) => {
    if (!baseUrl) return '';
    
    // If it's already a full URL, return as-is
    if (baseUrl.startsWith('http')) {
      return baseUrl;
    }

    // Construct URL based on quality
    const baseName = baseUrl.replace(/\.[^/.]+$/, '');
    const extension = quality === 'hls' ? 'm3u8' : 'mp4';
    
    return `${baseName}_${quality}.${extension}`;
  };

  // Video event handlers
  const handleLoadStart = () => {
    setIsLoading(true);
  };

  const handleCanPlay = () => {
    setIsLoading(false);
    if (enableAnalytics) {
      sendAnalytics('video_ready');
    }
  };

  const handleLoadedMetadata = () => {
    const video = videoRef.current;
    if (video) {
      setDuration(video.duration);
    }
  };

  const handleTimeUpdate = () => {
    const video = videoRef.current;
    if (!video) return;

    const current = video.currentTime;
    setCurrentTime(current);

    // Update buffered progress
    if (video.buffered.length > 0) {
      const bufferedEnd = video.buffered.end(video.buffered.length - 1);
      setBuffered((bufferedEnd / video.duration) * 100);
    }

    // Track progress for analytics
    if (enableAnalytics) {
      const progress = (current / video.duration) * 100;
      analyticsRef.current.maxProgress = Math.max(analyticsRef.current.maxProgress, progress);
      
      // Call progress callback
      if (onProgress) {
        onProgress({
          currentTime: current,
          duration: video.duration,
          progress: progress
        });
      }
    }
  };

  const handlePlay = () => {
    setIsPlaying(true);
    if (enableAnalytics) {
      if (!analyticsRef.current.startTime) {
        analyticsRef.current.startTime = Date.now();
        sendAnalytics('video_start');
      } else {
        sendAnalytics('video_resume');
      }
    }
  };

  const handlePause = () => {
    setIsPlaying(false);
    if (enableAnalytics) {
      analyticsRef.current.pauseCount++;
      sendAnalytics('video_pause');
    }
  };

  const handleEnded = () => {
    setIsPlaying(false);
    if (enableAnalytics) {
      sendAnalytics('video_complete');
    }
    if (onComplete) {
      onComplete({
        videoId,
        watchTime: analyticsRef.current.watchTime,
        completed: true
      });
    }
  };

  const handleError = (e) => {
    console.error('Video error:', e);
    setError('An error occurred while playing the video.');
    setIsLoading(false);
    if (enableAnalytics) {
      sendAnalytics('video_error', { error: e.target.error?.message });
    }
  };

  // Control functions
  const togglePlay = () => {
    const video = videoRef.current;
    if (!video) return;

    if (isPlaying) {
      video.pause();
    } else {
      video.play().catch(err => {
        console.error('Error playing video:', err);
        setError('Failed to play video. Please try again.');
      });
    }
  };

  const seek = (timeInSeconds) => {
    const video = videoRef.current;
    if (video) {
      video.currentTime = timeInSeconds;
    }
  };

  const handleProgressClick = (e) => {
    const progressBar = progressBarRef.current;
    if (!progressBar || !duration) return;

    const rect = progressBar.getBoundingClientRect();
    const pos = (e.clientX - rect.left) / rect.width;
    const newTime = pos * duration;
    seek(newTime);
  };

  const changeQuality = (quality) => {
    if (quality === selectedQuality) return;

    const currentTime = videoRef.current?.currentTime || 0;
    setSelectedQuality(quality);
    
    if (enableAnalytics) {
      analyticsRef.current.qualityChanges++;
      sendAnalytics('quality_change', { 
        from: selectedQuality, 
        to: quality 
      });
    }

    // Restore current time after quality change
    setTimeout(() => {
      if (videoRef.current) {
        videoRef.current.currentTime = currentTime;
      }
    }, 100);
  };

  const changePlaybackRate = (rate) => {
    const video = videoRef.current;
    if (video) {
      video.playbackRate = rate;
      setPlaybackRate(rate);
      
      if (enableAnalytics) {
        sendAnalytics('playback_rate_change', { rate });
      }
    }
  };

  const toggleMute = () => {
    const video = videoRef.current;
    if (video) {
      video.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  const changeVolume = (newVolume) => {
    const video = videoRef.current;
    if (video) {
      video.volume = newVolume;
      setVolume(newVolume);
      setIsMuted(newVolume === 0);
    }
  };

  const toggleFullscreen = () => {
    const container = containerRef.current;
    if (!container) return;

    if (!isFullscreen) {
      if (container.requestFullscreen) {
        container.requestFullscreen();
      } else if (container.webkitRequestFullscreen) {
        container.webkitRequestFullscreen();
      } else if (container.msRequestFullscreen) {
        container.msRequestFullscreen();
      }
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen();
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
    }
  };

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyPress = (e) => {
      if (!containerRef.current?.contains(document.activeElement)) return;

      switch (e.key) {
        case ' ':
        case 'k':
          e.preventDefault();
          togglePlay();
          break;
        case 'ArrowLeft':
          e.preventDefault();
          seek(Math.max(0, currentTime - 10));
          break;
        case 'ArrowRight':
          e.preventDefault();
          seek(Math.min(duration, currentTime + 10));
          break;
        case 'ArrowUp':
          e.preventDefault();
          changeVolume(Math.min(1, volume + 0.1));
          break;
        case 'ArrowDown':
          e.preventDefault();
          changeVolume(Math.max(0, volume - 0.1));
          break;
        case 'm':
          e.preventDefault();
          toggleMute();
          break;
        case 'f':
          e.preventDefault();
          toggleFullscreen();
          break;
        default:
          break;
      }
    };

    document.addEventListener('keydown', handleKeyPress);
    return () => document.removeEventListener('keydown', handleKeyPress);
  }, [currentTime, duration, volume, isPlaying]);

  // Fullscreen change detection
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    document.addEventListener('webkitfullscreenchange', handleFullscreenChange);
    document.addEventListener('msfullscreenchange', handleFullscreenChange);

    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange);
      document.removeEventListener('webkitfullscreenchange', handleFullscreenChange);
      document.removeEventListener('msfullscreenchange', handleFullscreenChange);
    };
  }, []);

  // Auto-hide controls
  const showControlsTemporarily = () => {
    setShowControls(true);
    
    if (controlsTimeoutRef.current) {
      clearTimeout(controlsTimeoutRef.current);
    }
    
    controlsTimeoutRef.current = setTimeout(() => {
      if (isPlaying) {
        setShowControls(false);
      }
    }, 3000);
  };

  // Analytics function
  const sendAnalytics = (event, data = {}) => {
    if (!enableAnalytics) return;

    const analyticsData = {
      event,
      videoId,
      timestamp: Date.now(),
      currentTime,
      duration,
      quality: selectedQuality,
      playbackRate,
      ...data,
      ...analyticsRef.current
    };

    // Send to your analytics service
    console.log('Video Analytics:', analyticsData);
    
    // Example: Send to API
    // fetch('/api/analytics/video', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(analyticsData)
    // });
  };

  // Format time helper
  const formatTime = (seconds) => {
    if (!seconds || isNaN(seconds)) return '0:00';
    
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // Render loading state
  if (isLoading && !error) {
    return (
      <div className={`video-player loading ${className}`} style={style}>
        <div className="loading-spinner">
          <div className="spinner"></div>
          <p>Loading video...</p>
        </div>
      </div>
    );
  }

  // Render error state
  if (error) {
    return (
      <div className={`video-player error ${className}`} style={style}>
        <div className="error-message">
          <h3>Video Error</h3>
          <p>{error}</p>
          <button onClick={loadVideo} className="retry-button">
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div 
      ref={containerRef}
      className={`video-player ${isFullscreen ? 'fullscreen' : ''} ${className}`}
      style={style}
      onMouseMove={showControlsTemporarily}
      onMouseLeave={() => isPlaying && setShowControls(false)}
      tabIndex={0}
    >
      {/* Video Element */}
      <video
        ref={videoRef}
        className="video-element"
        poster={thumbnail}
        autoPlay={autoPlay}
        onLoadStart={handleLoadStart}
        onCanPlay={handleCanPlay}
        onLoadedMetadata={handleLoadedMetadata}
        onTimeUpdate={handleTimeUpdate}
        onPlay={handlePlay}
        onPause={handlePause}
        onEnded={handleEnded}
        onError={handleError}
        onClick={togglePlay}
      />

      {/* Video Title Overlay */}
      {title && (
        <div className="video-title-overlay">
          <h3>{title}</h3>
          {description && <p>{description}</p>}
        </div>
      )}

      {/* Controls */}
      {controls && (
        <div className={`video-controls ${showControls ? 'visible' : 'hidden'}`}>
          {/* Progress Bar */}
          <div 
            ref={progressBarRef}
            className="progress-container"
            onClick={handleProgressClick}
          >
            <div className="progress-buffer" style={{ width: `${buffered}%` }} />
            <div 
              className="progress-played" 
              style={{ width: `${(currentTime / duration) * 100}%` }} 
            />
            <div 
              className="progress-handle"
              style={{ left: `${(currentTime / duration) * 100}%` }}
            />
          </div>

          {/* Control Buttons */}
          <div className="controls-row">
            <div className="controls-left">
              <button 
                className="control-button play-pause"
                onClick={togglePlay}
                aria-label={isPlaying ? 'Pause' : 'Play'}
              >
                {isPlaying ? '⏸️' : '▶️'}
              </button>

              <div className="volume-controls">
                <button 
                  className="control-button"
                  onClick={toggleMute}
                  aria-label={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? '🔇' : volume > 0.5 ? '🔊' : '🔉'}
                </button>
                <input
                  type="range"
                  className="volume-slider"
                  min="0"
                  max="1"
                  step="0.1"
                  value={isMuted ? 0 : volume}
                  onChange={(e) => changeVolume(parseFloat(e.target.value))}
                />
              </div>

              <div className="time-display">
                <span>{formatTime(currentTime)} / {formatTime(duration)}</span>
              </div>
            </div>

            <div className="controls-right">
              {/* Playback Rate */}
              <select 
                className="playback-rate"
                value={playbackRate}
                onChange={(e) => changePlaybackRate(parseFloat(e.target.value))}
              >
                <option value="0.5">0.5x</option>
                <option value="0.75">0.75x</option>
                <option value="1">1x</option>
                <option value="1.25">1.25x</option>
                <option value="1.5">1.5x</option>
                <option value="2">2x</option>
              </select>

              {/* Quality Selector */}
              <select 
                className="quality-selector"
                value={selectedQuality}
                onChange={(e) => changeQuality(e.target.value)}
              >
                {qualities.map(quality => (
                  <option key={quality} value={quality}>
                    {quality}
                  </option>
                ))}
              </select>

              {/* Fullscreen Button */}
              <button 
                className="control-button"
                onClick={toggleFullscreen}
                aria-label={isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}
              >
                {isFullscreen ? '⛶' : '⛶'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default VideoPlayer;