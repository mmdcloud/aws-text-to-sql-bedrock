// ─── Auth Types ────────────────────────────────────────────────────────────────
export interface User {
    sub: string;
    email: string;
    name?: string;
    given_name?: string;
    family_name?: string;
}

export interface AuthState {
    user: User | null;
    isAuthenticated: boolean;
    isLoading: boolean;
}

// ─── Query Types ────────────────────────────────────────────────────────────────
export interface QueryRequest {
    query: string;
}

export interface QueryResult {
    columns: string[];
    rows: Record<string, unknown>[];
}

export interface QueryResponse {
    sql: string;
    results: QueryResult;
    execution_time_ms?: number;
    message?: string;
}

export interface QueryHistoryItem {
    id: string;
    query: string;
    response: QueryResponse;
    timestamp: Date;
}

// ─── Document Types ─────────────────────────────────────────────────────────────
export type DocumentStatus = 'uploading' | 'processing' | 'ready' | 'error';

export interface Document {
    id: string;
    filename: string;
    size: number;
    status: DocumentStatus;
    uploaded_at: string;
    file_type: string;
}

export interface UploadProgress {
    file: File;
    progress: number;
    status: DocumentStatus;
    documentId?: string;
}

// ─── API Types ──────────────────────────────────────────────────────────────────
export interface ApiError {
    message: string;
    status?: number;
}
