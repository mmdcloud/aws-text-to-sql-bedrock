import React, { useState } from 'react';
import ReactPlayer from 'react-player';
import { Play, Pause, Volume2, VolumeX } from 'lucide-react';

const sampleVideos = [
  {
    id: '1',
    title: 'Big Buck Bunny',
    url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1516329901741-991f59171b4e?w=800&auto=format&fit=crop',
    duration: '10:35',
    views: '2.4k'
  },
  {
    id: '2',
    title: 'Elephant Dream',
    url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=800&auto=format&fit=crop',
    duration: '8:22',
    views: '1.8k'
  }
];

export default function MediaPlayer() {
  const [currentVideo, setCurrentVideo] = useState(sampleVideos[0]);
  const [playing, setPlaying] = useState(false);
  const [volume, setVolume] = useState(0.8);
  const [muted, setMuted] = useState(false);

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold text-gray-900">Media Player</h1>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <div className="aspect-w-16 aspect-h-9 bg-black rounded-xl overflow-hidden shadow-soft">
            <ReactPlayer
              url={currentVideo.url}
              width="100%"
              height="100%"
              playing={playing}
              volume={volume}
              muted={muted}
              controls={true}
              className="react-player"
            />
          </div>
          
          <div className="bg-white rounded-xl shadow-soft p-6 space-y-4">
            <h2 className="text-2xl font-semibold text-gray-900">{currentVideo.title}</h2>
            <div className="flex items-center space-x-6">
              <button
                onClick={() => setPlaying(!playing)}
                className="p-3 rounded-xl hover:bg-gray-100 transition-colors"
              >
                {playing ? (
                  <Pause className="h-6 w-6 text-gray-700" />
                ) : (
                  <Play className="h-6 w-6 text-gray-700" />
                )}
              </button>
              
              <button
                onClick={() => setMuted(!muted)}
                className="p-3 rounded-xl hover:bg-gray-100 transition-colors"
              >
                {muted ? (
                  <VolumeX className="h-6 w-6 text-gray-700" />
                ) : (
                  <Volume2 className="h-6 w-6 text-gray-700" />
                )}
              </button>
              
              <div className="flex-1">
                <input
                  type="range"
                  min={0}
                  max={1}
                  step={0.1}
                  value={volume}
                  onChange={(e) => setVolume(parseFloat(e.target.value))}
                  className="w-full"
                />
              </div>
            </div>
          </div>
        </div>
        
        <div className="space-y-4">
          <h2 className="text-xl font-semibold text-gray-900">Up Next</h2>
          <div className="bg-white rounded-xl shadow-soft overflow-hidden">
            {sampleVideos.map((video) => (
              <button
                key={video.id}
                onClick={() => setCurrentVideo(video)}
                className={`w-full text-left p-4 hover:bg-gray-50 transition-colors flex items-start space-x-4 ${
                  currentVideo.id === video.id ? 'bg-primary-50' : ''
                }`}
              >
                <div className="relative">
                  <img
                    src={video.thumbnail}
                    alt={video.title}
                    className="w-32 h-20 object-cover rounded-lg"
                  />
                  <span className="absolute bottom-2 right-2 bg-black bg-opacity-75 text-white text-xs px-2 py-1 rounded">
                    {video.duration}
                  </span>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 truncate">{video.title}</p>
                  <p className="text-sm text-gray-500 mt-1">{video.views} views</p>
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}