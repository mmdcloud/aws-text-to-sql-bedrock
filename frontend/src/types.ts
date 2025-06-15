export interface User {
  id: string;
  email: string;
  name: string;
}

export interface MediaItem {
  id: string;
  title: string;
  type: 'video' | 'audio';
  url: string;
  uploadedAt: string;
  uploadedBy: string;
}