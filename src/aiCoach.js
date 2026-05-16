import { config } from "./config.js";

function localReport(analysis) {
  const best = analysis.hourlyRanking[0];
  const worst = [...analysis.hourlyRanking].reverse()[0];
  const highStress = analysis.stressSeries.filter((item) => item.stress >= 70);

  return {
    provider: "local",
    summary: `평균 집중도는 ${analysis.averageFocus}점, 평균 스트레스는 ${analysis.averageStress}점입니다.`,
    bestTime: best ? `${best.hour} 전후가 현재 데이터상 가장 공부가 잘되는 시간대입니다.` : "아직 추천할 데이터가 부족합니다.",
    weakTime: worst ? `${worst.hour} 전후는 집중도가 낮게 측정되어 쉬운 복습이나 휴식으로 돌리는 편이 좋습니다.` : "아직 취약 시간대 데이터가 부족합니다.",
    coaching: highStress.length
      ? "스트레스가 높은 구간이 있습니다. HRV가 내려가고 심박이 올라가는 구간에서는 5분 휴식 후 다시 시작하세요."
      : "현재 스트레스는 최적 각성 구간에 가깝습니다. 이 패턴을 유지하면서 같은 시간대에 고난도 과목을 배치하세요.",
    nextActions: [
      best ? `${best.hour}에는 문제풀이 또는 구현 과제 배치` : "오늘 최소 2개 세션 기록",
      worst ? `${worst.hour}에는 암기 복습이나 가벼운 정리` : "HRV 샘플을 20분 간격으로 추가",
      "스트레스 70점 이상이면 짧은 회복 루틴 실행"
    ]
  };
}

function buildPrompt(analysis, userMessage = "") {
  return [
    "너는 StudyPuls의 학습 코치다.",
    "사용자의 HRV, 심박수, 스트레스 점수, 집중도 점수를 바탕으로 어느 시점에 공부가 잘되고 어느 시점에 공부가 잘 안되는지 코칭한다.",
    "의학적 진단처럼 말하지 말고, 학습 루틴 개선 조언으로만 답한다.",
    "반드시 JSON만 반환한다. 키는 summary, bestTime, weakTime, coaching, nextActions 배열을 사용한다.",
    "",
    `사용자 질문: ${userMessage || "오늘 학습 컨디션을 분석해줘"}`,
    `분석 데이터: ${JSON.stringify(analysis)}`
  ].join("\n");
}

async function callOpenAi(prompt) {
  const appConfig = config();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), appConfig.openAiTimeoutMs);

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    signal: controller.signal,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${appConfig.openAiApiKey}`
    },
    body: JSON.stringify({
      model: appConfig.openAiModel,
      input: prompt,
      text: {
        format: {
          type: "json_object"
        }
      }
    })
  });
  clearTimeout(timeout);

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`OpenAI request failed: ${response.status} ${detail.slice(0, 200)}`);
  }

  const payload = await response.json();
  const text = payload.output_text || payload.output?.flatMap((item) => item.content || [])
    .map((content) => content.text || "")
    .join("");

  if (!text) throw new Error("OpenAI returned an empty response");
  return JSON.parse(text);
}

export async function getCoaching(analysis, userMessage = "") {
  const fallback = localReport(analysis);
  if (!config().openAiEnabled) return fallback;

  try {
    const ai = await callOpenAi(buildPrompt(analysis, userMessage));
    return {
      provider: "openai",
      summary: ai.summary || fallback.summary,
      bestTime: ai.bestTime || fallback.bestTime,
      weakTime: ai.weakTime || fallback.weakTime,
      coaching: ai.coaching || fallback.coaching,
      nextActions: Array.isArray(ai.nextActions) ? ai.nextActions : fallback.nextActions
    };
  } catch (error) {
    return {
      ...fallback,
      provider: "local-fallback",
      warning: error.message
    };
  }
}
