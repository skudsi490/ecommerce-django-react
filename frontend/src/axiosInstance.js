// E:\DevOps\ecommerce-django-react\frontend\src\axiosInstance.js

import axios from 'axios';

const instance = axios.create({
  baseURL: 'http://localhost:8000', // Base URL for backend API
});

export default instance;
