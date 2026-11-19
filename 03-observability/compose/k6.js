import http from "k6/http";
import { check } from "k6";

export const options = {
  scenarios: {
    steady: {
      executor: "constant-arrival-rate",
      rate: Number(__ENV.RATE || 5),
      timeUnit: "1s",
      duration: __ENV.DURATION || "10m",
      preAllocatedVUs: 5,
      maxVUs: 20,
    },
  },
};

const target = __ENV.TARGET || "http://service:8080";

export default function () {
  const response = http.get(target + "/work");
  check(response, { "work returned 2xx": (r) => r.status >= 200 && r.status < 300 });
}

