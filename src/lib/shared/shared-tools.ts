import { PUBLIC_NODE_ENV } from '$env/static/public';

import { OBJECT_IDS } from './shared.constant';

export function formatTime(timestamp) {
  const date = new Date(parseInt(timestamp));

  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
}

export const linkifyGmId = (gmId) => {
  if (PUBLIC_NODE_ENV === 'development') {
    return `https://devnet.suivision.xyz/object/${gmId}`;
  }

  return `https://suivision.xyz/object/${gmId}`;
};

export const getObjectId = (key: string) => {
  if (PUBLIC_NODE_ENV === 'development') {
    return OBJECT_IDS?.development?.[key];
  }

  return OBJECT_IDS?.production?.[key];
};
