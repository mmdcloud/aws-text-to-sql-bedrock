import React, { useState, useCallback, useEffect } from 'react';
import { useDropzone } from 'react-dropzone';
import {
    Upload, FileText, File, Trash2, CheckCircle, AlertCircle,
    Loader2, RefreshCw, Search, BookOpen,
} from 'lucide-react';
import { uploadDocument, listDocuments, deleteDocument } from '../../api/documentsApi';
import type { Document, UploadProgress } from '../../types';
import './KnowledgeBasePage.css';

const ACCEPTED_TYPES = {
    'application/pdf': ['.pdf'],
    'text/plain': ['.txt'],
    'text/csv': ['.csv'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
};

const formatBytes = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
};

const getFileIcon = (type: string) => {
    if (type?.includes('pdf')) return '📄';
    if (type?.includes('csv')) return '📊';
    if (type?.includes('word') || type?.includes('docx')) return '📝';
    return '📃';
};

const StatusBadge = ({ status }: { status: Document['status'] }) => {
    const map = {
        ready: { cls: 'badge-success', label: 'Ready', icon: <CheckCircle size={11} /> },
        processing: { cls: 'badge-warning', label: 'Processing', icon: <Loader2 size={11} className="animate-spin" /> },
        uploading: { cls: 'badge-info', label: 'Uploading', icon: <Loader2 size={11} className="animate-spin" /> },
        error: { cls: 'badge-error', label: 'Error', icon: <AlertCircle size={11} /> },
    };
    const s = map[status] || map.error;
    return <span className={`badge ${s.cls}`}>{s.icon}{s.label}</span>;
};

const KnowledgeBasePage = () => {
    const [documents, setDocuments] = useState<Document[]>([]);
    const [uploadQueue, setUploadQueue] = useState<UploadProgress[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [deletingId, setDeletingId] = useState<string | null>(null);
    const [error, setError] = useState('');

    const fetchDocuments = useCallback(async () => {
        try {
            const docs = await listDocuments();
            setDocuments(docs);
        } catch {
            // API may not be connected yet in dev
            setDocuments([]);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => { fetchDocuments(); }, [fetchDocuments]);

    const onDrop = useCallback(async (acceptedFiles: File[]) => {
        setError('');
        const newItems: UploadProgress[] = acceptedFiles.map((file) => ({
            file,
            progress: 0,
            status: 'uploading',
        }));
        setUploadQueue((q) => [...q, ...newItems]);

        await Promise.all(
            acceptedFiles.map(async (file, idx) => {
                try {
                    const doc = await uploadDocument(file, (progress) => {
                        setUploadQueue((q) =>
                            q.map((item, i) => (item.file === file ? { ...item, progress } : item))
                        );
                    });
                    setUploadQueue((q) =>
                        q.map((item) =>
                            item.file === file
                                ? { ...item, status: 'ready', progress: 100, documentId: doc.id }
                                : item
                        )
                    );
                    setDocuments((d) => [doc, ...d]);
                } catch {
                    setUploadQueue((q) =>
                        q.map((item) => (item.file === file ? { ...item, status: 'error' } : item))
                    );
                }
            })
        );

        // Clear completed uploads after 3s
        setTimeout(() => {
            setUploadQueue((q) => q.filter((item) => item.status === 'error'));
        }, 3000);
    }, []);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        accept: ACCEPTED_TYPES,
        maxSize: 50 * 1024 * 1024, // 50MB
    });

    const handleDelete = async (id: string) => {
        setDeletingId(id);
        try {
            await deleteDocument(id);
            setDocuments((d) => d.filter((doc) => doc.id !== id));
        } catch {
            setError('Failed to delete document.');
        } finally {
            setDeletingId(null);
        }
    };

    const filtered = documents.filter((d) =>
        d.filename?.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div className="kb-page">
            {/* Header */}
            <div className="kb-header animate-fade-in-up">
                <div className="kb-header-info">
                    <div className="kb-header-icon"><BookOpen size={22} /></div>
                    <div>
                        <h2 className="kb-header-title">Knowledge Base</h2>
                        <p className="kb-header-sub">Upload documents to enrich your SQL query context</p>
                    </div>
                </div>
                <div className="kb-stats">
                    <div className="kb-stat">
                        <span className="kb-stat-value">{documents.length}</span>
                        <span className="kb-stat-label">Documents</span>
                    </div>
                    <div className="kb-stat">
                        <span className="kb-stat-value">
                            {documents.filter((d) => d.status === 'ready').length}
                        </span>
                        <span className="kb-stat-label">Ready</span>
                    </div>
                </div>
            </div>

            {/* Drop Zone */}
            <div
                {...getRootProps()}
                className={`dropzone animate-fade-in-up stagger-1 ${isDragActive ? 'dropzone--active' : ''}`}
            >
                <input {...getInputProps()} />
                <div className="dropzone-icon">
                    <Upload size={32} />
                </div>
                <div className="dropzone-text">
                    <p className="dropzone-title">
                        {isDragActive ? 'Drop files here...' : 'Drag & drop files here'}
                    </p>
                    <p className="dropzone-sub">or click to browse</p>
                </div>
                <div className="dropzone-formats">
                    <span>PDF</span><span>CSV</span><span>TXT</span><span>DOCX</span>
                    <span className="dropzone-limit">Max 50 MB per file</span>
                </div>
            </div>

            {/* Upload Queue */}
            {uploadQueue.length > 0 && (
                <div className="upload-queue animate-fade-in-up">
                    {uploadQueue.map((item, i) => (
                        <div key={i} className="upload-item card">
                            <div className="upload-item-info">
                                <span className="upload-item-name">{item.file.name}</span>
                                <StatusBadge status={item.status} />
                            </div>
                            {item.status === 'uploading' && (
                                <div className="upload-progress-bar">
                                    <div
                                        className="upload-progress-fill"
                                        style={{ width: `${item.progress}%` }}
                                    />
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* Error */}
            {error && (
                <div className="auth-error animate-fade-in" style={{ borderRadius: 'var(--radius-lg)' }}>
                    <AlertCircle size={16} /><span>{error}</span>
                </div>
            )}

            {/* Document List */}
            <div className="doc-list-section animate-fade-in-up stagger-2">
                <div className="doc-list-header">
                    <h3 className="doc-list-title">Documents</h3>
                    <div className="doc-list-actions">
                        <div className="input-wrapper" style={{ width: 240 }}>
                            <Search size={15} className="input-icon" />
                            <input
                                type="text"
                                className="input-with-icon"
                                placeholder="Search documents..."
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                style={{ padding: '0.5rem 0.75rem 0.5rem 2.5rem', fontSize: '0.875rem' }}
                            />
                        </div>
                        <button
                            className="btn btn-secondary btn-sm"
                            onClick={fetchDocuments}
                            aria-label="Refresh"
                        >
                            <RefreshCw size={14} />Refresh
                        </button>
                    </div>
                </div>

                {isLoading ? (
                    <div className="doc-list-loading">
                        {[...Array(3)].map((_, i) => (
                            <div key={i} className="skeleton doc-skeleton" />
                        ))}
                    </div>
                ) : filtered.length === 0 ? (
                    <div className="doc-list-empty card">
                        <FileText size={40} />
                        <p>{searchTerm ? 'No documents match your search.' : 'No documents yet. Upload your first document above.'}</p>
                    </div>
                ) : (
                    <div className="doc-grid">
                        {filtered.map((doc, i) => (
                            <div key={doc.id} className={`doc-card card animate-fade-in-up stagger-${Math.min(i + 1, 5)}`}>
                                <div className="doc-card-top">
                                    <span className="doc-card-emoji">{getFileIcon(doc.file_type)}</span>
                                    <StatusBadge status={doc.status} />
                                </div>
                                <div className="doc-card-body">
                                    <p className="doc-card-name" title={doc.filename}>{doc.filename}</p>
                                    <p className="doc-card-meta">
                                        {formatBytes(doc.size)} · {new Date(doc.uploaded_at).toLocaleDateString()}
                                    </p>
                                </div>
                                <div className="doc-card-actions">
                                    <button
                                        className="btn btn-danger btn-sm"
                                        onClick={() => handleDelete(doc.id)}
                                        disabled={deletingId === doc.id}
                                    >
                                        {deletingId === doc.id
                                            ? <Loader2 size={13} className="animate-spin" />
                                            : <Trash2 size={13} />}
                                        Delete
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};

export default KnowledgeBasePage;
