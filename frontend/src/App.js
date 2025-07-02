import React, { useState, useEffect } from 'react';
import { Layout, Typography, Card, Space, message } from 'antd';
import NaturalLanguageInput from './components/NaturalLanguageInput';
import DynamicControls from './components/DynamicControls';
import VisualizationPanel from './components/VisualizationPanel';
import MetricsPanel from './components/MetricsPanel';
import { ApiService } from './services/ApiService';
import { GeminiService } from './services/GeminiService';
import './App.css';

const { Header, Content } = Layout;
const { Title, Text } = Typography;

// Example configuration for demo
const DEMO_CONFIG = {
  template: "work_scheduling",
  indexes: {
    days: {
      type: "date_range",
      start: "2025-07-01",
      end: "2025-07-07"
    },
    candidates: {
      type: "list",
      values: ["Alice", "Bob", "Carol", "David", "Emma"]
    },
    skills: {
      type: "list", 
      values: ["kitchen", "wait", "service", "cleaning"]
    },
    scenarios: {
      type: "list",
      values: ["base", "high_demand"]
    }
  },
  parameters: {
    demand: {
      type: "table",
      schema: ["scenario", "day", "skill", "value"],
      source: {
        type: "override",
        data: [
          ["base", "2025-07-01", "kitchen", 2],
          ["base", "2025-07-01", "wait", 3],
          ["base", "2025-07-01", "service", 1],
          ["base", "2025-07-01", "cleaning", 1],
          ["high_demand", "2025-07-01", "kitchen", 3],
          ["high_demand", "2025-07-01", "wait", 4],
          ["high_demand", "2025-07-01", "service", 2],
          ["high_demand", "2025-07-01", "cleaning", 1]
        ]
      }
    },
    candidate_skills: {
      type: "table",
      schema: ["candidate", "skill", "has_skill"],
      source: {
        type: "override",
        data: [
          ["Alice", "kitchen", true],
          ["Alice", "wait", true],
          ["Alice", "service", false],
          ["Alice", "cleaning", true],
          ["Bob", "kitchen", true],
          ["Bob", "wait", false],
          ["Bob", "service", true],
          ["Bob", "cleaning", true],
          ["Carol", "kitchen", false],
          ["Carol", "wait", true],
          ["Carol", "service", true],
          ["Carol", "cleaning", false],
          ["David", "kitchen", true],
          ["David", "wait", true],
          ["David", "service", true],
          ["David", "cleaning", true],
          ["Emma", "kitchen", false],
          ["Emma", "wait", true],
          ["Emma", "service", true],
          ["Emma", "cleaning", true]
        ]
      }
    },
    cost_month: {
      type: "dict",
      key: "candidate",
      source: {
        type: "override",
        data: {
          "Alice": 3500,
          "Bob": 3200,
          "Carol": 3800,
          "David": 4000,
          "Emma": 3300
        }
      }
    }
  },
  options: {
    max_daily_assignments: 2
  },
  overrides: {
    objective: [{
      name: "cost_optimization",
      function: "minimize_cost_objective",
      args: { multiplier: 1.0 }
    }]
  }
};

function App() {
  const [modelId, setModelId] = useState(null);
  const [uiSpec, setUiSpec] = useState(null);
  const [solution, setSolution] = useState(null);
  const [loading, setLoading] = useState(false);
  const [controls, setControls] = useState({});

  useEffect(() => {
    initializeDemo();
  }, []);

  const initializeDemo = async () => {
    try {
      setLoading(true);
      
      // Create model with demo configuration
      const model = await ApiService.createModel(DEMO_CONFIG);
      setModelId(model.model_id);
      
      // Get UI specification
      const ui = await ApiService.createUISpec(model.model_id, "");
      setUiSpec(ui);
      
      // Initialize controls with default values
      const initialControls = {};
      ui.controls.forEach(control => {
        initialControls[control.maps_to] = control.default;
      });
      setControls(initialControls);
      
      message.success('Demo initialized successfully!');
    } catch (error) {
      message.error('Failed to initialize demo: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleNaturalLanguageQuery = async (query) => {
    try {
      setLoading(true);
      
      // Get current UI state for context
      const currentUIState = {
        controls: controls,
        uiSpec: uiSpec,
        modelId: modelId
      };
      
      // Parse natural language query using Gemini
      const nlpResult = await GeminiService.parseNaturalLanguageQuery(query, currentUIState);
      
      console.log('NLP Result:', nlpResult);
      
      // Apply UI updates directly
      if (nlpResult.ui_updates && nlpResult.ui_updates.length > 0) {
        const updatedControls = { ...controls };
        
        nlpResult.ui_updates.forEach(update => {
          updatedControls[update.control_id] = update.value;
          message.info(`Updated ${update.control_id}: ${update.explanation}`);
        });
        
        setControls(updatedControls);
      }
      
      // Apply config patches to model if any
      if (nlpResult.config_patches && nlpResult.config_patches.length > 0) {
        await ApiService.updateModelConfig(modelId, { patches: nlpResult.config_patches });
      }
      
      // Update visualization focus if specified
      if (nlpResult.visualization_focus) {
        // Store focus for visualization component
        setSolution(prev => ({
          ...prev,
          visualization_focus: nlpResult.visualization_focus
        }));
      }
      
      message.success('Query processed successfully!');
      
    } catch (error) {
      console.error('Natural language processing error:', error);
      message.error('Failed to process query: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleControlChange = async (controlId, value) => {
    try {
      const updatedControls = { ...controls, [controlId]: value };
      setControls(updatedControls);
      
      // Create patch for the control change
      const patch = {
        operation: "merge",
        path: controlId.split('.'),
        value: value
      };
      
      // Apply patch to model
      await ApiService.updateModelConfig(modelId, { patches: [patch] });
      
      message.success('Control updated successfully!');
    } catch (error) {
      message.error('Failed to update control: ' + error.message);
    }
  };

  const handleSolveModel = async () => {
    try {
      setLoading(true);
      
      // Solve the model
      const result = await ApiService.solveModel(modelId);
      setSolution(result);
      
      if (result.status === 'OPTIMAL') {
        message.success('Model solved successfully!');
      } else {
        message.warning(`Model solved with status: ${result.status}`);
      }
    } catch (error) {
      message.error('Failed to solve model: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout className="app-layout">
      <Header className="app-header">
        <Title level={2} style={{ color: 'white', margin: 0 }}>
          SchedulingDSL Demo
        </Title>
        <Text style={{ color: 'rgba(255,255,255,0.8)' }}>
          Natural Language Workforce Optimization
        </Text>
      </Header>
      
      <Content className="app-content">
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          {/* Natural Language Input */}
          <Card title="Natural Language Query">
            <NaturalLanguageInput 
              onQuery={handleNaturalLanguageQuery}
              loading={loading}
            />
          </Card>

          {/* Dynamic Controls */}
          {uiSpec && (
            <Card title="Interactive Controls">
              <DynamicControls
                controls={uiSpec.controls}
                values={controls}
                onChange={handleControlChange}
                onSolve={handleSolveModel}
                loading={loading}
              />
            </Card>
          )}

          {/* Visualization */}
          {solution && (
            <Card title="Optimization Results">
              <VisualizationPanel
                solution={solution}
                uiSpec={uiSpec}
                controls={controls}
              />
            </Card>
          )}

          {/* Metrics */}
          {solution && (
            <Card title="Performance Metrics">
              <MetricsPanel
                solution={solution}
                metrics={uiSpec?.metrics || []}
              />
            </Card>
          )}
        </Space>
      </Content>
    </Layout>
  );
}

export default App;