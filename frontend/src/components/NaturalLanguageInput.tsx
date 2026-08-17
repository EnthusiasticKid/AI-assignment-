/** Natural language query input component. */

import React, { useState } from "react";
import { Input, Button, Space, Typography, Alert, Card } from "antd";
import { DownloadOutlined, PlayCircleOutlined, SendOutlined, LoadingOutlined } from "@ant-design/icons";

const { TextArea } = Input;
const { Text } = Typography;

interface NaturalLanguageInputProps {
  onGenerateSQL: (prompt: string) => void;
  loading?: boolean;
  error?: string | null;
  generatedSql?: string | null;
  onExecute?: () => void;
  onExecuteAndExport?: (format: "csv" | "json") => void;
  executing?: boolean;
  exporting?: "csv" | "json" | null;
}

export const NaturalLanguageInput: React.FC<NaturalLanguageInputProps> = ({
  onGenerateSQL,
  loading = false,
  error = null,
  generatedSql = null,
  onExecute,
  onExecuteAndExport,
  executing = false,
  exporting = null,
}) => {
  const [prompt, setPrompt] = useState("");

  const handleSubmit = () => {
    if (prompt.trim()) {
      onGenerateSQL(prompt.trim());
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    // Submit on Cmd/Ctrl + Enter
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      handleSubmit();
    }
  };

  return (
    <Space direction="vertical" style={{ width: "100%" }} size={12}>
      <div>
        <Text strong style={{ fontSize: 13, textTransform: "uppercase" }}>
          Describe your query in natural language
        </Text>
        <Text type="secondary" style={{ fontSize: 12, marginLeft: 8 }}>
          (English or Chinese)
        </Text>
      </div>

      <TextArea
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="例如：查询所有未完成的任务
或：Show me all active users from the last 30 days"
        rows={4}
        style={{
          fontSize: 15,
          borderWidth: 2,
          borderRadius: 2,
        }}
        disabled={loading}
      />

      {error && (
        <Alert
          message="Generation Failed"
          description={error}
          type="error"
          closable
          style={{ borderWidth: 2 }}
        />
      )}

      {generatedSql && (
        <Card
          size="small"
          title="Generated SQL"
          style={{ borderWidth: 2, background: "#F8F8F7" }}
        >
          <pre
            style={{
              margin: "0 0 16px",
              padding: 12,
              overflowX: "auto",
              background: "#FFFFFF",
              border: "1px solid #D9D9D9",
              whiteSpace: "pre-wrap",
            }}
          >
            {generatedSql}
          </pre>
          <Space wrap>
            <Button
              type="primary"
              icon={<PlayCircleOutlined />}
              onClick={onExecute}
              loading={executing}
            >
              EXECUTE QUERY
            </Button>
            <Button
              icon={<DownloadOutlined />}
              onClick={() => onExecuteAndExport?.("csv")}
              loading={exporting === "csv"}
            >
              EXECUTE & EXPORT CSV
            </Button>
            <Button
              icon={<DownloadOutlined />}
              onClick={() => onExecuteAndExport?.("json")}
              loading={exporting === "json"}
            >
              EXECUTE & EXPORT JSON
            </Button>
          </Space>
          <Text type="secondary" style={{ display: "block", marginTop: 12 }}>
            Review the generated SQL before executing. Switch to Manual SQL if you want to edit it.
          </Text>
        </Card>
      )}

      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <Text type="secondary" style={{ fontSize: 12 }}>
          Press Cmd/Ctrl + Enter to generate
        </Text>
        <Button
          type="primary"
          icon={loading ? <LoadingOutlined /> : <SendOutlined />}
          onClick={handleSubmit}
          loading={loading}
          disabled={!prompt.trim() || loading}
          size="large"
          style={{
            height: 40,
            paddingLeft: 20,
            paddingRight: 20,
            fontWeight: 700,
          }}
        >
          GENERATE SQL
        </Button>
      </div>
    </Space>
  );
};
