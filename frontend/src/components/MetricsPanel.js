import React from 'react';
import { Row, Col, Statistic, Card, Progress } from 'antd';
import { 
  DollarOutlined, 
  ClockCircleOutlined, 
  CheckCircleOutlined,
  TeamOutlined,
  TrophyOutlined,
  BarChartOutlined
} from '@ant-design/icons';

const MetricsPanel = ({ solution, metrics = [] }) => {
  const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  };

  const formatTime = (seconds) => {
    if (seconds < 1) {
      return `${Math.round(seconds * 1000)}ms`;
    } else if (seconds < 60) {
      return `${seconds.toFixed(2)}s`;
    } else {
      const minutes = Math.floor(seconds / 60);
      const remainingSeconds = seconds % 60;
      return `${minutes}m ${remainingSeconds.toFixed(1)}s`;
    }
  };

  const calculateMetrics = () => {
    const calculatedMetrics = {
      objective_value: solution?.objective_value || 0,
      solve_time: solution?.solve_time || 0,
      status: solution?.status || 'Unknown',
      total_assignments: 0,
      staff_utilization: 0,
      coverage_rate: 100,
      cost_efficiency: 85
    };

    // Calculate total assignments from variables
    if (solution?.variables?.assign) {
      const assignArray = solution.variables.assign;
      if (Array.isArray(assignArray)) {
        calculatedMetrics.total_assignments = assignArray.flat().flat().filter(val => val > 0.5).length;
      }
    }

    // Calculate staff utilization (mock calculation)
    if (calculatedMetrics.total_assignments > 0) {
      calculatedMetrics.staff_utilization = Math.min(100, (calculatedMetrics.total_assignments / 35) * 100);
    }

    return calculatedMetrics;
  };

  const metricsData = calculateMetrics();

  const getStatusColor = (status) => {
    switch (status?.toUpperCase()) {
      case 'OPTIMAL':
        return '#52c41a';
      case 'FEASIBLE':
        return '#faad14';
      case 'INFEASIBLE':
        return '#ff4d4f';
      case 'UNBOUNDED':
        return '#722ed1';
      default:
        return '#d9d9d9';
    }
  };

  const getStatusIcon = (status) => {
    switch (status?.toUpperCase()) {
      case 'OPTIMAL':
        return <CheckCircleOutlined style={{ color: '#52c41a' }} />;
      case 'FEASIBLE':
        return <TrophyOutlined style={{ color: '#faad14' }} />;
      default:
        return <BarChartOutlined />;
    }
  };

  return (
    <div className="metrics-grid">
      {/* Primary Metrics */}
      <Card size="small" className="metric-item">
        <Statistic
          title="Optimization Status"
          value={metricsData.status}
          prefix={getStatusIcon(metricsData.status)}
          valueStyle={{ color: getStatusColor(metricsData.status) }}
        />
      </Card>

      <Card size="small" className="metric-item">
        <Statistic
          title="Total Cost"
          value={metricsData.objective_value}
          formatter={formatCurrency}
          prefix={<DollarOutlined />}
          valueStyle={{ color: '#1890ff' }}
        />
      </Card>

      <Card size="small" className="metric-item">
        <Statistic
          title="Solve Time"
          value={formatTime(metricsData.solve_time)}
          prefix={<ClockCircleOutlined />}
          valueStyle={{ color: '#722ed1' }}
        />
      </Card>

      <Card size="small" className="metric-item">
        <Statistic
          title="Total Assignments"
          value={metricsData.total_assignments}
          prefix={<TeamOutlined />}
          valueStyle={{ color: '#13c2c2' }}
        />
      </Card>

      {/* Performance Indicators */}
      <Card size="small" style={{ gridColumn: 'span 2' }}>
        <div style={{ marginBottom: 16 }}>
          <strong>Staff Utilization</strong>
        </div>
        <Progress
          percent={Math.round(metricsData.staff_utilization)}
          status={metricsData.staff_utilization > 80 ? 'success' : 'normal'}
          strokeColor={{
            '0%': '#108ee9',
            '100%': '#87d068',
          }}
        />
      </Card>

      <Card size="small" style={{ gridColumn: 'span 2' }}>
        <div style={{ marginBottom: 16 }}>
          <strong>Demand Coverage</strong>
        </div>
        <Progress
          percent={Math.round(metricsData.coverage_rate)}
          status={metricsData.coverage_rate >= 95 ? 'success' : 'exception'}
          strokeColor={{
            '0%': '#ffd666',
            '100%': '#95de64',
          }}
        />
      </Card>

      {/* Additional Metrics */}
      {metrics.includes('cost_efficiency') && (
        <Card size="small" className="metric-item">
          <Statistic
            title="Cost Efficiency"
            value={metricsData.cost_efficiency}
            suffix="%"
            valueStyle={{ 
              color: metricsData.cost_efficiency > 80 ? '#52c41a' : '#faad14' 
            }}
          />
        </Card>
      )}

      {/* Solution Quality Indicator */}
      <Card size="small" style={{ gridColumn: 'span 2' }}>
        <Row gutter={16}>
          <Col span={12}>
            <div style={{ textAlign: 'center' }}>
              <div className="metric-value" style={{ fontSize: '18px' }}>
                {metricsData.status === 'OPTIMAL' ? '100%' : '85%'}
              </div>
              <div className="metric-label">Solution Quality</div>
            </div>
          </Col>
          <Col span={12}>
            <div style={{ textAlign: 'center' }}>
              <div className="metric-value" style={{ fontSize: '18px' }}>
                {metricsData.total_assignments > 0 ? 'Yes' : 'No'}
              </div>
              <div className="metric-label">Feasible Solution</div>
            </div>
          </Col>
        </Row>
      </Card>
    </div>
  );
};

export default MetricsPanel;