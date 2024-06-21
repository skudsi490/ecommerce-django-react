// frontend/src/axiosInstance.js
import axios from 'axios';

const isLocal = window.location.hostname === 'localhost';

const backendURL = isLocal ? 'http://localhost:8000' : 'http://backend:8000';

const axiosInstance = axios.create({
  baseURL: backendURL, // Base URL for backend API
});

export default axiosInstance;
