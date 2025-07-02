import React, { useMemo } from 'react';
import { Card, Row, Col, Table, Empty } from 'antd';
import Plot from 'react-plotly.js';

const VisualizationPanel = ({ solution, uiSpec, controls }) => {
  // Process solution data for visualization
  const processedData = useMemo(() => {
    if (!solution?.variables) return null;

    const assignments = [];
    const scheduleData = [];
    
    // Extract assignment variables
    Object.entries(solution.variables).forEach(([varName, varValue]) => {
      if (varName === 'assign' && Array.isArray(varValue)) {
        // Process 3D assignment array [candidates, days, skills]
        const candidates = controls['indexes.candidates'] || ['Alice', 'Bob', 'Carol', 'David', 'Emma'];
        const skills = controls['indexes.skills'] || ['kitchen', 'wait', 'service', 'cleaning'];
        const dateRange = controls['indexes.days'] || ['2025-07-01', '2025-07-07'];
        
        // Generate date array
        const startDate = new Date(dateRange[0]);
        const endDate = new Date(dateRange[1]);
        const days = [];
        for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
          days.push(new Date(d).toISOString().split('T')[0]);
        }

        candidates.forEach((candidate, candidateIdx) => {
          days.forEach((day, dayIdx) => {
            skills.forEach((skill, skillIdx) => {
              const value = varValue[candidateIdx]?.[dayIdx]?.[skillIdx] || 0;
              if (value > 0.5) { // Binary variable threshold
                assignments.push({
                  candidate,
                  day,
                  skill,
                  value: Math.round(value)
                });
                
                scheduleData.push({
                  candidate,
                  task: `${skill} (${day})`,
                  start: `${day}T09:00:00`,
                  finish: `${day}T17:00:00`,
                  skill,
                  day
                });
              }
            });
          });
        });
      }
    });

    return { assignments, scheduleData };
  }, [solution, controls]);

  const createGanttChart = () => {
    if (!processedData?.scheduleData.length) {
      return <Empty description="No schedule data available" />;
    }

    const colors = {
      kitchen: '#ff7f0e',
      wait: '#2ca02c', 
      service: '#d62728',
      cleaning: '#9467bd'
    };

    const traces = processedData.scheduleData.map((item, index) => ({
      x: [item.start, item.finish],
      y: [item.candidate, item.candidate],
      type: 'scatter',
      mode: 'lines',
      line: {
        color: colors[item.skill] || '#1f77b4',
        width: 20
      },
      hovertemplate: `
        <b>%{y}</b><br>
        Task: ${item.task}<br>
        Skill: ${item.skill}<br>
        <extra></extra>
      `,
      name: item.skill,
      showlegend: index === 0 || !processedData.scheduleData.slice(0, index).some(prev => prev.skill === item.skill)
    }));

    return (
      <Plot
        data={traces}
        layout={{
          title: 'Staff Schedule (Gantt Chart)',
          xaxis: {
            title: 'Time',
            type: 'date'
          },
          yaxis: {
            title: 'Staff Member'
          },
          height: 400,
          margin: { l: 100, r: 50, t: 50, b: 50 },
          hovermode: 'closest'
        }}
        config={{
          displayModeBar: true,
          displaylogo: false,
          modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d']
        }}
        style={{ width: '100%' }}
      />
    );
  };

  const createHeatmap = () => {
    if (!processedData?.assignments.length) {
      return <Empty description="No assignment data available" />;
    }

    // Create heatmap data
    const candidates = [...new Set(processedData.assignments.map(a => a.candidate))];
    const skills = [...new Set(processedData.assignments.map(a => a.skill))];
    
    const heatmapData = skills.map(skill => 
      candidates.map(candidate => {
        const assignments = processedData.assignments.filter(
          a => a.candidate === candidate && a.skill === skill
        );
        return assignments.length;
      })
    );

    const heatmapTrace = {
      z: heatmapData,
      x: candidates,
      y: skills,
      type: 'heatmap',
      colorscale: 'Blues',
      hoveringtemplate: '%{y} - %{x}: %{z} assignments<extra></extra>'
    };

    return (
      <Plot
        data={[heatmapTrace]}
        layout={{
          title: 'Assignment Heatmap (Skills vs Staff)',
          xaxis: { title: 'Staff Member' },
          yaxis: { title: 'Skill' },
          height: 300,
          margin: { l: 100, r: 50, t: 50, b: 50 }
        }}
        config={{
          displayModeBar: true,
          displaylogo: false,
          modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d']
        }}
        style={{ width: '100%' }}
      />
    );
  };

  const createWorkloadChart = () => {
    if (!processedData?.assignments.length) {
      return <Empty description="No workload data available" />;
    }

    // Calculate workload per person
    const workloadData = {};
    processedData.assignments.forEach(assignment => {
      workloadData[assignment.candidate] = (workloadData[assignment.candidate] || 0) + 1;
    });

    const candidates = Object.keys(workloadData);
    const workloads = Object.values(workloadData);

    const trace = {
      x: candidates,
      y: workloads,
      type: 'bar',
      marker: {
        color: 'rgba(55, 128, 191, 0.7)',
        line: {
          color: 'rgba(55, 128, 191, 1.0)',
          width: 2
        }
      },
      hovertemplate: '%{x}: %{y} assignments<extra></extra>'
    };

    return (
      <Plot
        data={[trace]}
        layout={{
          title: 'Workload Distribution',
          xaxis: { title: 'Staff Member' },
          yaxis: { title: 'Number of Assignments' },
          height: 300,
          margin: { l: 50, r: 50, t: 50, b: 50 }
        }}
        config={{
          displayModeBar: true,
          displaylogo: false,
          modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d']
        }}
        style={{ width: '100%' }}
      />
    );
  };

  const createAssignmentTable = () => {
    if (!processedData?.assignments.length) {
      return <Empty description="No assignment data available" />;
    }

    const columns = [
      {
        title: 'Staff Member',
        dataIndex: 'candidate',
        key: 'candidate',
        sorter: (a, b) => a.candidate.localeCompare(b.candidate)
      },
      {
        title: 'Date',
        dataIndex: 'day',
        key: 'day',
        sorter: (a, b) => new Date(a.day) - new Date(b.day)
      },
      {
        title: 'Skill/Role',
        dataIndex: 'skill',
        key: 'skill',
        sorter: (a, b) => a.skill.localeCompare(b.skill)
      },
      {
        title: 'Assignment',
        dataIndex: 'value',
        key: 'value',
        render: (value) => value === 1 ? '✓ Assigned' : '○ Not Assigned'
      }
    ];

    return (
      <Table
        dataSource={processedData.assignments.map((item, index) => ({
          ...item,
          key: index
        }))}
        columns={columns}
        pagination={{ pageSize: 10 }}
        size="small"
        scroll={{ y: 400 }}
      />
    );
  };

  if (!solution) {
    return <Empty description="Run optimization to see results" />;
  }

  return (
    <div className="visualization-grid">
      <div>
        <Row gutter={[16, 16]}>
          <Col span={24}>
            <Card title="Schedule Overview" size="small">
              {createGanttChart()}
            </Card>
          </Col>
          
          <Col xs={24} lg={12}>
            <Card title="Skill Assignment Matrix" size="small">
              {createHeatmap()}
            </Card>
          </Col>
          
          <Col xs={24} lg={12}>
            <Card title="Workload Balance" size="small">
              {createWorkloadChart()}
            </Card>
          </Col>
        </Row>
      </div>
      
      <div>
        <Card title="Assignment Details" size="small">
          {createAssignmentTable()}
        </Card>
      </div>
    </div>
  );
};

export default VisualizationPanel;