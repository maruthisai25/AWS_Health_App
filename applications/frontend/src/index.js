// applications/frontend/src/index.js

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

// Performance monitoring (optional)
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

const root = ReactDOM.createRoot(document.getElementById('root'));

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// Measure performance in your app
function sendToAnalytics(metric) {
  // TODO: Send to your analytics service
  console.log('Web Vitals:', metric);
}

// Report web vitals
getCLS(sendToAnalytics);
getFID(sendToAnalytics);
getFCP(sendToAnalytics);
getLCP(sendToAnalytics);
getTTFB(sendToAnalytics);
