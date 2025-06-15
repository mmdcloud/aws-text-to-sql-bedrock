import axios from 'axios';

const axiosInstanceWithBlob = axios.create({
	// Configuration
	baseURL: 'http://localhost:3001',
	timeout: 10000,
	headers:{
		Accept:"multipart/form-data"
	}
});

// axiosInstance.interceptors.response.use(config => {
// 	if(config.status == 401)
// 	{
// 		return window.location.href = '/auth/signin'
// 	}
// 	return config;
// });

export default axiosInstanceWithBlob;