import axiosClient from './axiosClient';
import type { QueryRequest, QueryResponse } from '../types';

export const sendQuery = async (payload: QueryRequest): Promise<QueryResponse> => {
    const { data } = await axiosClient.post<QueryResponse>('/query', payload);
    return data;
};

export const getQueryHistory = async (): Promise<QueryResponse[]> => {
    const { data } = await axiosClient.get<QueryResponse[]>('/query/history');
    return data;
};
