import axios from 'axios';

class GeminiService {
  constructor() {
    this.apiKey = process.env.REACT_APP_GEMINI_API_KEY;
    this.baseURL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
    
    if (!this.apiKey) {
      console.warn('Gemini API key not found in environment variables');
    }
  }

  async parseNaturalLanguageQuery(query, currentUIState = {}) {
    if (!this.apiKey) {
      throw new Error('Gemini API key not configured');
    }

    const prompt = this.buildPrompt(query, currentUIState);
    
    try {
      const response = await axios.post(
        `${this.baseURL}?key=${this.apiKey}`,
        {
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 1500,
            topP: 0.8,
            topK: 40
          }
        },
        {
          headers: {
            'Content-Type': 'application/json',
          }
        }
      );

      if (response.data?.candidates?.[0]?.content?.parts?.[0]?.text) {
        const responseText = response.data.candidates[0].content.parts[0].text;
        return this.parseGeminiResponse(responseText);
      } else {
        throw new Error('Invalid response format from Gemini API');
      }
    } catch (error) {
      console.error('Gemini API error:', error);
      
      // Fallback to simple parsing
      return this.fallbackParsing(query, currentUIState);
    }
  }

  buildPrompt(query, currentUIState) {
    return `You are an expert UI configurator for workforce scheduling optimization. Convert natural language queries into UI control updates and configuration patches.

CURRENT UI STATE:
${JSON.stringify(currentUIState, null, 2)}

AVAILABLE UI CONTROLS:
- Date Range Picker (maps to "indexes.days"): Select scheduling period
- Staff Selection (maps to "indexes.candidates"): Choose which staff members
- Skill Selection (maps to "indexes.skills"): Select skills/roles
- Scenario Selection (maps to "indexes.scenarios"): Choose demand scenarios
- Demand Multiplier Sliders (maps to "parameters.demand.*_multiplier"): Adjust demand levels
- Cost Multiplier Sliders (maps to "parameters.cost_month.multiplier"): Adjust staff costs
- Max Daily Assignments (maps to "options.max_daily_assignments"): Work limits per person

UI CONTROL TYPES:
- date_range: {start: "YYYY-MM-DD", end: "YYYY-MM-DD"}
- slider: numeric value (0.1 to 3.0 for multipliers)
- multiselect: array of selected values
- number: integer or float value

RESPONSE FORMAT:
Return a JSON object with:
{
  "ui_updates": [
    {
      "control_id": "string (maps_to value)",
      "value": "new value for the control",
      "explanation": "why this control was updated"
    }
  ],
  "config_patches": [
    {
      "operation": "merge",
      "path": ["path", "to", "config"],
      "value": "new value"
    }
  ],
  "visualization_focus": "string describing what to highlight in visualizations"
}

EXAMPLES:

Query: "Show me next week's schedule"
Response: {
  "ui_updates": [
    {
      "control_id": "indexes.days",
      "value": ["2025-07-08", "2025-07-14"],
      "explanation": "Set date range to next week"
    }
  ],
  "config_patches": [
    {
      "operation": "merge",
      "path": ["indexes", "days"],
      "value": {"type": "date_range", "start": "2025-07-08", "end": "2025-07-14"}
    }
  ],
  "visualization_focus": "weekly_schedule"
}

Query: "Increase kitchen demand by 50% and show the impact"
Response: {
  "ui_updates": [
    {
      "control_id": "parameters.demand.kitchen_multiplier",
      "value": 1.5,
      "explanation": "Increase kitchen demand by 50%"
    }
  ],
  "config_patches": [
    {
      "operation": "merge",
      "path": ["parameters", "demand", "kitchen_multiplier"],
      "value": 1.5
    }
  ],
  "visualization_focus": "kitchen_assignments"
}

Query: "Alice can only work 10am to 4pm shifts"
Response: {
  "ui_updates": [],
  "config_patches": [
    {
      "operation": "merge",
      "path": ["overrides", "constraints"],
      "value": [{"name": "alice_time_window", "function": "time_window_constraint", "args": {"candidate": "Alice", "start_time": 10, "end_time": 16}}]
    }
  ],
  "visualization_focus": "alice_schedule"
}

CURRENT QUERY: "${query}"

Respond with only valid JSON. No explanation or additional text.`;
  }

  parseGeminiResponse(responseText) {
    try {
      // Clean up the response text to extract JSON
      let jsonText = responseText.trim();
      
      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.slice(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.slice(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.slice(0, -3);
      }
      
      jsonText = jsonText.trim();
      
      const parsed = JSON.parse(jsonText);
      
      // Validate the response structure
      if (!parsed.ui_updates || !Array.isArray(parsed.ui_updates)) {
        parsed.ui_updates = [];
      }
      if (!parsed.config_patches || !Array.isArray(parsed.config_patches)) {
        parsed.config_patches = [];
      }
      if (!parsed.visualization_focus) {
        parsed.visualization_focus = 'general';
      }
      
      return parsed;
    } catch (error) {
      console.error('Failed to parse Gemini response:', responseText, error);
      throw new Error('Invalid JSON response from Gemini API');
    }
  }

  fallbackParsing(query, currentUIState) {
    const queryLower = query.toLowerCase();
    const uiUpdates = [];
    const configPatches = [];
    let visualizationFocus = 'general';

    // Time-related queries
    if (queryLower.includes('next week')) {
      const today = new Date();
      const nextWeekStart = new Date(today);
      nextWeekStart.setDate(today.getDate() + ((7 - today.getDay()) % 7) + 1);
      const nextWeekEnd = new Date(nextWeekStart);
      nextWeekEnd.setDate(nextWeekStart.getDate() + 6);

      const startStr = nextWeekStart.toISOString().split('T')[0];
      const endStr = nextWeekEnd.toISOString().split('T')[0];

      uiUpdates.push({
        control_id: 'indexes.days',
        value: [startStr, endStr],
        explanation: 'Set date range to next week'
      });

      visualizationFocus = 'weekly_schedule';
    }

    // Demand adjustments
    if (queryLower.includes('demand')) {
      let multiplier = 1.0;
      
      if (queryLower.includes('high') || queryLower.includes('increase')) {
        multiplier = 1.5;
      } else if (queryLower.includes('low') || queryLower.includes('decrease')) {
        multiplier = 0.7;
      }

      if (queryLower.includes('kitchen')) {
        uiUpdates.push({
          control_id: 'parameters.demand.kitchen_multiplier',
          value: multiplier,
          explanation: `Adjust kitchen demand to ${multiplier}x`
        });
        visualizationFocus = 'kitchen_assignments';
      }
    }

    // Cost adjustments
    if (queryLower.includes('cost') && (queryLower.includes('adjust') || queryLower.includes('increase') || queryLower.includes('decrease'))) {
      let multiplier = queryLower.includes('decrease') ? 0.8 : 1.2;
      
      // Extract percentage if mentioned
      const percentMatch = queryLower.match(/(\d+)%/);
      if (percentMatch) {
        const percent = parseInt(percentMatch[1]);
        multiplier = queryLower.includes('decrease') ? 1 - (percent / 100) : 1 + (percent / 100);
      }

      uiUpdates.push({
        control_id: 'parameters.cost_month.multiplier',
        value: multiplier,
        explanation: `Adjust staff costs to ${multiplier}x`
      });
      visualizationFocus = 'cost_analysis';
    }

    return {
      ui_updates: uiUpdates,
      config_patches: configPatches,
      visualization_focus: visualizationFocus
    };
  }

  // Helper method to extract time ranges from natural language
  extractTimeRange(query) {
    const queryLower = query.toLowerCase();
    const today = new Date();

    if (queryLower.includes('today')) {
      const todayStr = today.toISOString().split('T')[0];
      return [todayStr, todayStr];
    }

    if (queryLower.includes('this week')) {
      const startOfWeek = new Date(today);
      startOfWeek.setDate(today.getDate() - today.getDay());
      const endOfWeek = new Date(startOfWeek);
      endOfWeek.setDate(startOfWeek.getDate() + 6);
      
      return [
        startOfWeek.toISOString().split('T')[0],
        endOfWeek.toISOString().split('T')[0]
      ];
    }

    if (queryLower.includes('next month')) {
      const nextMonth = new Date(today);
      nextMonth.setMonth(today.getMonth() + 1);
      nextMonth.setDate(1);
      const endOfMonth = new Date(nextMonth);
      endOfMonth.setMonth(nextMonth.getMonth() + 1);
      endOfMonth.setDate(0);
      
      return [
        nextMonth.toISOString().split('T')[0],
        endOfMonth.toISOString().split('T')[0]
      ];
    }

    return null;
  }

  // Helper method to extract staff member names
  extractStaffNames(query) {
    const staffNames = ['Alice', 'Bob', 'Carol', 'David', 'Emma'];
    const mentioned = staffNames.filter(name => 
      query.toLowerCase().includes(name.toLowerCase())
    );
    return mentioned.length > 0 ? mentioned : null;
  }

  // Helper method to extract skills/roles
  extractSkills(query) {
    const skills = ['kitchen', 'wait', 'service', 'cleaning'];
    const mentioned = skills.filter(skill => 
      query.toLowerCase().includes(skill)
    );
    return mentioned.length > 0 ? mentioned : null;
  }
}

// Export singleton instance
const geminiServiceInstance = new GeminiService();
export { geminiServiceInstance as GeminiService };
export default geminiServiceInstance;