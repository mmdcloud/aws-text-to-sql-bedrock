import React, { useState, useRef, useEffect } from 'react';
import {
    Send, Copy, Download, Clock, Sparkles, Database,
    ChevronDown, ChevronUp, CheckCheck, Loader2, AlertCircle,
} from 'lucide-react';
import { sendQuery } from '../../api/queryApi';
import type { QueryHistoryItem, QueryResponse } from '../../types';
import './DashboardPage.css';

const exampleQueries = [
    'Show me the top 10 customers by revenue this year',
    'What are the total sales by product category last quarter?',
    'List all orders that are pending shipment',
    'Which regions have the highest return rates?',
];

const ResultTable = ({ results }: { results: QueryResponse['results'] }) => {
    if (!results?.columns?.length) return null;
    return (
        <div className="result-table-wrapper">
            <table className="data-table">
                <thead>
                    <tr>{results.columns.map((col) => <th key={col}>{col}</th>)}</tr>
                </thead>
                <tbody>
                    {results.rows.map((row, i) => (
                        <tr key={i}>
                            {results.columns.map((col) => (
                                <td key={col}>{String(row[col] ?? '')}</td>
                            ))}
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
};

const DashboardPage = () => {
    const [query, setQuery] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [history, setHistory] = useState<QueryHistoryItem[]>([]);
    const [expandedItems, setExpandedItems] = useState<Set<string>>(new Set());
    const [copiedId, setCopiedId] = useState<string | null>(null);
    const [error, setError] = useState('');
    const textareaRef = useRef<HTMLTextAreaElement>(null);
    const resultsEndRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (history.length) {
            resultsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
        }
    }, [history]);

    const autoResize = () => {
        const el = textareaRef.current;
        if (el) {
            el.style.height = 'auto';
            el.style.height = Math.min(el.scrollHeight, 200) + 'px';
        }
    };

    const handleSubmit = async (e?: React.FormEvent) => {
        e?.preventDefault();
        const trimmed = query.trim();
        if (!trimmed || isLoading) return;
        setError('');
        setIsLoading(true);
        try {
            const response = await sendQuery({ query: trimmed });
            const item: QueryHistoryItem = {
                id: Date.now().toString(),
                query: trimmed,
                response,
                timestamp: new Date(),
            };
            setHistory((h) => [item, ...h]);
            setExpandedItems((s) => new Set([...s, item.id]));
            setQuery('');
            if (textareaRef.current) textareaRef.current.style.height = 'auto';
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Failed to process query. Please try again.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSubmit();
        }
    };

    const copySQL = async (id: string, sql: string) => {
        await navigator.clipboard.writeText(sql);
        setCopiedId(id);
        setTimeout(() => setCopiedId(null), 2000);
    };

    const exportCSV = (item: QueryHistoryItem) => {
        const { columns, rows } = item.response.results;
        if (!columns?.length) return;
        const csvContent = [
            columns.join(','),
            ...rows.map((row) => columns.map((c) => `"${String(row[c] ?? '')}"`).join(',')),
        ].join('\n');
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `query-${item.id}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    const toggleExpand = (id: string) => {
        setExpandedItems((s) => {
            const next = new Set(s);
            next.has(id) ? next.delete(id) : next.add(id);
            return next;
        });
    };

    const formatTime = (date: Date) =>
        date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });

    return (
        <div className="dashboard-page">
            {/* Intro Banner */}
            <div className="dashboard-banner animate-fade-in-up">
                <div className="dashboard-banner-icon">
                    <Sparkles size={22} />
                </div>
                <div>
                    <h2 className="dashboard-banner-title">Query your database in plain English</h2>
                    <p className="dashboard-banner-sub">
                        Powered by AWS Bedrock — Describe what you want, and we'll generate the SQL and fetch the results.
                    </p>
                </div>
            </div>

            {/* Example Queries */}
            {!history.length && (
                <div className="example-queries animate-fade-in-up stagger-1">
                    <p className="example-queries-label">Try an example</p>
                    <div className="example-queries-grid">
                        {exampleQueries.map((q) => (
                            <button key={q} className="example-query-chip" onClick={() => setQuery(q)}>
                                <Database size={14} />
                                <span>{q}</span>
                            </button>
                        ))}
                    </div>
                </div>
            )}

            {/* Results History */}
            {history.length > 0 && (
                <div className="query-history">
                    {history.map((item, idx) => {
                        const isExpanded = expandedItems.has(item.id);
                        return (
                            <div
                                key={item.id}
                                className={`history-item animate-fade-in-up card`}
                                style={{ animationDelay: `${idx * 0.05}s` }}
                            >
                                {/* Query Header */}
                                <div className="history-item-header" onClick={() => toggleExpand(item.id)}>
                                    <div className="history-item-query">
                                        <div className="history-item-query-icon">
                                            <Sparkles size={14} />
                                        </div>
                                        <span>{item.query}</span>
                                    </div>
                                    <div className="history-item-meta">
                                        <span className="history-item-time">
                                            <Clock size={12} />{formatTime(item.timestamp)}
                                        </span>
                                        {item.response.execution_time_ms && (
                                            <span className="badge badge-info">
                                                {item.response.execution_time_ms}ms
                                            </span>
                                        )}
                                        {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                                    </div>
                                </div>

                                {/* Expanded Results */}
                                {isExpanded && (
                                    <div className="history-item-results animate-fade-in-down">
                                        {/* Generated SQL */}
                                        {item.response.sql && (
                                            <div className="sql-block">
                                                <div className="sql-block-header">
                                                    <span className="sql-block-label">Generated SQL</span>
                                                    <button
                                                        className="btn btn-secondary btn-sm"
                                                        onClick={() => copySQL(item.id, item.response.sql)}
                                                    >
                                                        {copiedId === item.id
                                                            ? <><CheckCheck size={13} />Copied!</>
                                                            : <><Copy size={13} />Copy SQL</>}
                                                    </button>
                                                </div>
                                                <pre className="code-block">{item.response.sql}</pre>
                                            </div>
                                        )}

                                        {/* Results Table */}
                                        {item.response.results?.rows?.length > 0 ? (
                                            <div className="result-section">
                                                <div className="result-section-header">
                                                    <span className="result-section-label">
                                                        Results — {item.response.results.rows.length} rows
                                                    </span>
                                                    <button
                                                        className="btn btn-secondary btn-sm"
                                                        onClick={() => exportCSV(item)}
                                                    >
                                                        <Download size={13} />Export CSV
                                                    </button>
                                                </div>
                                                <ResultTable results={item.response.results} />
                                            </div>
                                        ) : (
                                            <div className="result-empty">
                                                <Database size={20} />
                                                <span>{item.response.message || 'Query executed, no rows returned.'}</span>
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        );
                    })}
                    <div ref={resultsEndRef} />
                </div>
            )}

            {/* Error */}
            {error && (
                <div className="auth-error animate-fade-in" style={{ borderRadius: 'var(--radius-lg)' }}>
                    <AlertCircle size={16} /><span>{error}</span>
                </div>
            )}

            {/* Query Input */}
            <div className="query-input-wrapper animate-fade-in-up">
                <form onSubmit={handleSubmit} className="query-input-form">
                    <div className="query-input-box">
                        <textarea
                            ref={textareaRef}
                            className="query-textarea"
                            placeholder="Ask anything about your data... (Enter to send, Shift+Enter for new line)"
                            value={query}
                            onChange={(e) => { setQuery(e.target.value); autoResize(); }}
                            onKeyDown={handleKeyDown}
                            rows={1}
                            disabled={isLoading}
                        />
                        <button
                            type="submit"
                            className="query-send-btn"
                            disabled={!query.trim() || isLoading}
                            aria-label="Send query"
                        >
                            {isLoading ? <Loader2 size={20} className="animate-spin" /> : <Send size={20} />}
                        </button>
                    </div>
                    <p className="query-hint">Press Enter to send · Shift+Enter for new line</p>
                </form>
            </div>
        </div>
    );
};

export default DashboardPage;
