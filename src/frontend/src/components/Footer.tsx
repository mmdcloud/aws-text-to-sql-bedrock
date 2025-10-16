import React from 'react';

export default function Footer() {
  return (
    <footer className="bg-gray-800 text-white py-8">
      <div className="container mx-auto px-4">
        {/* <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div>
            <h3 className="text-xl font-bold mb-4">MediaApp</h3>
            <p className="text-gray-400">
              Your one-stop solution for media management and playback.
            </p>
          </div>
          <div>
            <h4 className="text-lg font-semibold mb-4">Quick Links</h4>
            <ul className="space-y-2 text-gray-400">
              <li><a href="/dashboard" className="hover:text-white">Dashboard</a></li>
              <li><a href="/upload" className="hover:text-white">Upload Media</a></li>
              <li><a href="/media-player" className="hover:text-white">Media Player</a></li>
            </ul>
          </div>
          <div>
            <h4 className="text-lg font-semibold mb-4">Contact</h4>
            <p className="text-gray-400">
              Email: support@mediaapp.com<br />
              Phone: (555) 123-4567
            </p>
          </div>
        </div> */}
        <div className="border-gray-700 text-center text-gray-400">
          <p>&copy; {new Date().getFullYear()} MediaApp. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}