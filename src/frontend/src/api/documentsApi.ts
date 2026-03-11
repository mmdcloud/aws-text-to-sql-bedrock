import axiosClient from './axiosClient';
import type { Document } from '../types';

export const uploadDocument = async (
    file: File,
    onProgress?: (progress: number) => void
): Promise<Document> => {
    const formData = new FormData();
    formData.append('file', file);

    const { data } = await axiosClient.post<Document>('/documents', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: (progressEvent) => {
            if (progressEvent.total && onProgress) {
                const pct = Math.round((progressEvent.loaded * 100) / progressEvent.total);
                onProgress(pct);
            }
        },
    });
    return data;
};

export const listDocuments = async (): Promise<Document[]> => {
    const { data } = await axiosClient.get<Document[]>('/documents');
    return data;
};

export const deleteDocument = async (id: string): Promise<void> => {
    await axiosClient.delete(`/documents/${id}`);
};
