## Sentiment Analysis
> Analyze customer feedback sentiment for routing and reporting.

### When to Use
- Prioritizing negative feedback for immediate attention
- Tracking customer satisfaction trends over time
- Routing angry customers to senior support agents

### Configuration / Code

```xml
<flow name="sentiment-analysis">
    <http:listener config-ref="HTTP_Listener" path="/analyze-sentiment" method="POST"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="Analyze the sentiment of the following text. Return JSON: {sentiment: POSITIVE|NEGATIVE|NEUTRAL, confidence: 0.0-1.0, keyPhrases: []}"/>
            <ai:message role="user" content="#[payload.text]"/>
        </ai:messages>
        <ai:parameters temperature="0" maxTokens="100"/>
    </ai:chat-completions>
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
var result = read(payload.choices[0].message.content, "application/json")
---
result]]></ee:set-payload></ee:message>
    </ee:transform>
    <!-- Route based on sentiment -->
    <choice>
        <when expression="#[payload.sentiment == NEGATIVE and payload.confidence > 0.8]">
            <flow-ref name="escalate-to-senior-agent"/>
        </when>
        <otherwise>
            <flow-ref name="standard-processing"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Customer text is sent to the LLM for sentiment analysis
2. `temperature=0` ensures consistent classification
3. Response includes sentiment label, confidence score, and key phrases
4. High-confidence negative sentiment triggers escalation

### Gotchas
- Sarcasm and irony are hard for LLMs — may misclassify
- Multilingual content needs model support for the relevant languages
- For high-volume analysis, consider fine-tuned models over general LLMs
- Confidence thresholds should be calibrated on your specific data

### Related
- [Email Classifier](../email-classifier/) — classification patterns
- [Content Moderation](../../inference/content-moderation/) — content safety
