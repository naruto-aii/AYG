import { dispatch } from "../relay/http.mjs";

export const maxDuration = 120;

export function GET(request) {
  return dispatch(request);
}

export function POST(request) {
  return dispatch(request);
}

export function OPTIONS(request) {
  return dispatch(request);
}
