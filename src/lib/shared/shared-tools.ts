export function formatTime(timestamp) {
  const date = new Date(parseInt(timestamp));

  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
}

export const linkifyGmId = (gmId) => {
  return `https://devnet.suivision.xyz/object/${gmId}`;
};
