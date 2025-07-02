import axios from 'axios';

// Base URL for the Julia API
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';

class ApiService {
  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        console.log(`Making ${config.method?.toUpperCase()} request to ${config.url}`);
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        return response.data;
      },
      (error) => {
        console.error('API Error:', error.response?.data || error.message);
        throw new Error(error.response?.data?.message || error.message);
      }
    );
  }

  // Health check
  async healthCheck() {
    return await this.client.get('/');
  }

  // Model management
  async createModel(config) {
    return await this.client.post('/models', config);
  }

  async listModels() {
    return await this.client.get('/models');
  }

  async getModel(modelId) {
    return await this.client.get(`/models/${modelId}`);
  }

  async updateModelConfig(modelId, patches) {
    return await this.client.patch(`/models/${modelId}/config`, patches);
  }

  async deleteModel(modelId) {
    return await this.client.delete(`/models/${modelId}`);
  }

  // Model solving
  async solveModel(modelId) {
    return await this.client.post(`/models/${modelId}/solve`);
  }

  async getSolution(modelId) {
    return await this.client.get(`/models/${modelId}/solution`);
  }

  // UI specification
  async createUISpec(modelId, query = '') {
    return await this.client.post(`/models/${modelId}/ui-spec`, { query });
  }

  // Note: Natural language processing is now handled in the frontend via GeminiService

  // Helper methods for common operations
  async createAndSolveModel(config) {
    try {
      // Create model
      const model = await this.createModel(config);
      console.log('Model created:', model.model_id);

      // Solve model
      const solution = await this.solveModel(model.model_id);
      console.log('Model solved:', solution.status);

      return {
        model,
        solution
      };
    } catch (error) {
      console.error('Error in createAndSolveModel:', error);
      throw error;
    }
  }

  async updateAndSolveModel(modelId, patches) {
    try {
      // Update config
      await this.updateModelConfig(modelId, patches);
      console.log('Model config updated');

      // Solve model
      const solution = await this.solveModel(modelId);
      console.log('Model solved:', solution.status);

      return solution;
    } catch (error) {
      console.error('Error in updateAndSolveModel:', error);
      throw error;
    }
  }

  // Batch operations
  async batchUpdateControls(modelId, controlUpdates) {
    const patches = controlUpdates.map(update => ({
      operation: 'merge',
      path: update.path.split('.'),
      value: update.value
    }));

    return await this.updateModelConfig(modelId, { patches });
  }
}

// Export singleton instance
const apiServiceInstance = new ApiService();
export { apiServiceInstance as ApiService };
export default apiServiceInstance;