import React, { useState } from 'react';
import { Input, Button, Space, Tag, Card } from 'antd';
import { SendOutlined, BulbOutlined } from '@ant-design/icons';

const { TextArea } = Input;

const EXAMPLE_QUERIES = [
  "Show me next week's schedule",
  "Increase kitchen demand by 50%",
  "Adjust staff costs by 20%",
  "Alice can only work 10am to 4pm shifts",
  "Set high demand scenario for this weekend",
  "Reduce cleaning requirements by 30%",
  "Focus on wait staff optimization",
  "Show cost impact of weekend scheduling"
];

const NaturalLanguageInput = ({ onQuery, loading }) => {
  const [query, setQuery] = useState('');

  const handleSubmit = () => {
    if (query.trim()) {
      onQuery(query);
      // Don't clear the query so user can see what they asked
    }
  };

  const handleExampleClick = (exampleQuery) => {
    setQuery(exampleQuery);
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && e.ctrlKey) {
      handleSubmit();
    }
  };

  return (
    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
      <div>
        <TextArea
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Describe what you want to optimize or analyze in natural language...

Examples:
• Show me next week's schedule
• Increase kitchen demand by 50%
• Alice can only work 10am to 4pm shifts
• Adjust staff costs by 20%

Press Ctrl+Enter to submit"
          rows={4}
          className="natural-language-input"
        />
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Button 
          type="primary" 
          icon={<SendOutlined />}
          onClick={handleSubmit}
          loading={loading}
          disabled={!query.trim()}
          size="large"
        >
          Analyze Query
        </Button>
        
        <span style={{ color: '#666', fontSize: '12px' }}>
          Ctrl+Enter to submit
        </span>
      </div>

      <Card 
        size="small" 
        title={
          <span>
            <BulbOutlined style={{ marginRight: 8 }} />
            Try these example queries
          </span>
        }
        style={{ background: '#fafafa' }}
      >
        <Space wrap>
          {EXAMPLE_QUERIES.map((example, index) => (
            <Tag
              key={index}
              className="query-suggestion"
              onClick={() => handleExampleClick(example)}
              style={{ cursor: 'pointer', marginBottom: 8 }}
            >
              {example}
            </Tag>
          ))}
        </Space>
      </Card>
    </Space>
  );
};

export default NaturalLanguageInput;