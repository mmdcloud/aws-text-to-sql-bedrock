import React, { useState } from 'react';
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  getPaginationRowModel,
  useReactTable,
} from '@tanstack/react-table';
import { ChevronLeft, ChevronRight, Video, Music } from 'lucide-react';
import type { MediaItem } from '../types';

const columnHelper = createColumnHelper<MediaItem>();

const columns = [
  columnHelper.accessor('title', {
    header: 'Title',
    cell: info => (
      <div className="flex items-center space-x-3">
        {info.row.original.type === 'video' ? (
          <Video className="h-5 w-5 text-primary-500" />
        ) : (
          <Music className="h-5 w-5 text-primary-500" />
        )}
        <span>{info.getValue()}</span>
      </div>
    ),
  }),
  columnHelper.accessor('type', {
    header: 'Type',
    cell: info => (
      <span className={`px-3 py-1 rounded-full text-xs font-medium ${
        info.getValue() === 'video' 
          ? 'bg-blue-100 text-blue-800' 
          : 'bg-purple-100 text-purple-800'
      }`}>
        {info.getValue()}
      </span>
    ),
  }),
  columnHelper.accessor('uploadedAt', {
    header: 'Uploaded At',
    cell: info => (
      <span className="text-gray-600">
        {new Date(info.getValue()).toLocaleDateString(undefined, {
          year: 'numeric',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        })}
      </span>
    ),
  }),
  columnHelper.accessor('uploadedBy', {
    header: 'Uploaded By',
    cell: info => info.getValue(),
  }),
];

const data: MediaItem[] = [
  {
    id: '1',
    title: 'Introduction Video',
    type: 'video',
    url: 'https://example.com/video1',
    uploadedAt: '2024-03-10T10:00:00Z',
    uploadedBy: 'John Doe',
  },
  {
    id: '2',
    title: 'Background Music',
    type: 'audio',
    url: 'https://example.com/audio1',
    uploadedAt: '2024-03-09T15:30:00Z',
    uploadedBy: 'Jane Smith',
  },
  {
    id: '3',
    title: 'Product Demo',
    type: 'video',
    url: 'https://example.com/video2',
    uploadedAt: '2024-03-08T09:15:00Z',
    uploadedBy: 'Mike Johnson',
  },
];

export default function Dashboard() {
  const [sorting, setSorting] = useState([]);

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Media Dashboard</h1>
        <div className="flex items-center space-x-4">
          <select
            className="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm rounded-lg"
            value={table.getState().pagination.pageSize}
            onChange={e => {
              table.setPageSize(Number(e.target.value));
            }}
          >
            {[5, 10, 20].map(pageSize => (
              <option key={pageSize} value={pageSize}>
                Show {pageSize}
              </option>
            ))}
          </select>
        </div>
      </div>
      
      <div className="bg-white rounded-xl shadow-soft overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                {table.getFlatHeaders().map(header => (
                  <th
                    key={header.id}
                    className="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                  >
                    {flexRender(
                      header.column.columnDef.header,
                      header.getContext()
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {table.getRowModel().rows.map(row => (
                <tr key={row.id} className="table-row-hover">
                  {row.getVisibleCells().map(cell => (
                    <td
                      key={cell.id}
                      className="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                    >
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        <div className="px-6 py-4 bg-gray-50 border-t border-gray-200">
          <div className="flex items-center justify-between">
            <div className="flex-1 text-sm text-gray-700">
              Showing{' '}
              <span className="font-medium">
                {table.getState().pagination.pageIndex * table.getState().pagination.pageSize + 1}
              </span>{' '}
              to{' '}
              <span className="font-medium">
                {Math.min(
                  (table.getState().pagination.pageIndex + 1) * table.getState().pagination.pageSize,
                  table.getPrePaginationRowModel().rows.length
                )}
              </span>{' '}
              of{' '}
              <span className="font-medium">{table.getPrePaginationRowModel().rows.length}</span>{' '}
              results
            </div>
            <div className="flex items-center space-x-2">
              <button
                onClick={() => table.previousPage()}
                disabled={!table.getCanPreviousPage()}
                className="relative inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
              <button
                onClick={() => table.nextPage()}
                disabled={!table.getCanNextPage()}
                className="relative inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}