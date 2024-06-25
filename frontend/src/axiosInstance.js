// frontend/src/axiosInstance.js
import axios from 'axios';

const backendURL = process.env.REACT_APP_BACKEND_URL || 'http://3.67.70.116:8000';

const axiosInstance = axios.create({
  baseURL: backendURL, // Base URL for backend API
});

export default axiosInstance;
