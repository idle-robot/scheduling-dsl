import React from 'react';
import { 
  Slider, 
  DatePicker, 
  Select, 
  Button, 
  Space, 
  Card, 
  Row, 
  Col,
  InputNumber,
  Switch
} from 'antd';
import { PlayCircleOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';

const { RangePicker } = DatePicker;
const { Option } = Select;

const DynamicControls = ({ controls, values, onChange, onSolve, loading }) => {
  const renderControl = (control) => {
    const { type, label, maps_to, ...props } = control;
    const value = values[maps_to];

    const handleChange = (newValue) => {
      onChange(maps_to, newValue);
    };

    switch (type) {
      case 'slider':
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <Slider
              min={props.min || 0}
              max={props.max || 100}
              step={props.step || 1}
              value={value || props.default || 1}
              onChange={handleChange}
              marks={{
                [props.min || 0]: String(props.min || 0),
                [props.max || 100]: String(props.max || 100)
              }}
              tooltip={{ formatter: (val) => `${val}${props.unit || ''}` }}
            />
            <div style={{ textAlign: 'center', marginTop: 8, fontWeight: 'bold' }}>
              {value || props.default || 1}{props.unit || ''}
            </div>
          </div>
        );

      case 'date_range':
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <RangePicker
              value={value ? [dayjs(value[0]), dayjs(value[1])] : null}
              onChange={(dates) => {
                if (dates) {
                  handleChange([dates[0].format('YYYY-MM-DD'), dates[1].format('YYYY-MM-DD')]);
                }
              }}
              style={{ width: '100%' }}
            />
          </div>
        );

      case 'multiselect':
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <Select
              mode="multiple"
              value={value || props.default || []}
              onChange={handleChange}
              style={{ width: '100%' }}
              placeholder={`Select ${label}`}
            >
              {props.options?.map(option => (
                <Option key={option} value={option}>{option}</Option>
              ))}
            </Select>
          </div>
        );

      case 'select':
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <Select
              value={value || props.default}
              onChange={handleChange}
              style={{ width: '100%' }}
              placeholder={`Select ${label}`}
            >
              {props.options?.map(option => (
                <Option key={option} value={option}>{option}</Option>
              ))}
            </Select>
          </div>
        );

      case 'number':
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <InputNumber
              min={props.min}
              max={props.max}
              step={props.step || 1}
              value={value || props.default}
              onChange={handleChange}
              style={{ width: '100%' }}
              placeholder={label}
            />
          </div>
        );

      case 'switch':
        return (
          <div key={maps_to} className="control-item">
            <Space>
              <Switch
                checked={value || props.default || false}
                onChange={handleChange}
              />
              <label className="control-label">{label}</label>
            </Space>
          </div>
        );

      default:
        return (
          <div key={maps_to} className="control-item">
            <label className="control-label">{label}</label>
            <div style={{ padding: '8px', background: '#f5f5f5', borderRadius: '4px' }}>
              Unsupported control type: {type}
            </div>
          </div>
        );
    }
  };

  const organizeControls = () => {
    const organized = {
      time: [],
      parameters: [],
      constraints: [],
      other: []
    };

    controls.forEach(control => {
      if (control.type === 'date_range' || control.maps_to.includes('days')) {
        organized.time.push(control);
      } else if (control.maps_to.includes('parameters')) {
        organized.parameters.push(control);
      } else if (control.maps_to.includes('constraints')) {
        organized.constraints.push(control);
      } else {
        organized.other.push(control);
      }
    });

    return organized;
  };

  const organizedControls = organizeControls();

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }}>
      {/* Time Controls */}
      {organizedControls.time.length > 0 && (
        <Card title="Time Period" size="small">
          <Row gutter={[16, 16]}>
            {organizedControls.time.map(control => (
              <Col xs={24} sm={12} md={8} key={control.maps_to}>
                {renderControl(control)}
              </Col>
            ))}
          </Row>
        </Card>
      )}

      {/* Parameter Controls */}
      {organizedControls.parameters.length > 0 && (
        <Card title="Parameters" size="small">
          <Row gutter={[16, 16]}>
            {organizedControls.parameters.map(control => (
              <Col xs={24} sm={12} md={8} key={control.maps_to}>
                {renderControl(control)}
              </Col>
            ))}
          </Row>
        </Card>
      )}

      {/* Other Controls */}
      {organizedControls.other.length > 0 && (
        <Card title="Other Settings" size="small">
          <Row gutter={[16, 16]}>
            {organizedControls.other.map(control => (
              <Col xs={24} sm={12} md={8} key={control.maps_to}>
                {renderControl(control)}
              </Col>
            ))}
          </Row>
        </Card>
      )}

      {/* Solve Button */}
      <div style={{ textAlign: 'center', paddingTop: 16 }}>
        <Button
          type="primary"
          size="large"
          icon={<PlayCircleOutlined />}
          onClick={onSolve}
          loading={loading}
          style={{ 
            minWidth: 200,
            height: 48,
            fontSize: 16,
            borderRadius: 24
          }}
        >
          {loading ? 'Optimizing...' : 'Run Optimization'}
        </Button>
      </div>
    </Space>
  );
};

export default DynamicControls;