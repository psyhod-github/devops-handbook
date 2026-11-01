# 18 · Kubernetes: ресурсы и HPA — задания

## Уровень 1 — повторение главы

1. Включите metrics-server, посмотрите `kubectl top pods`.
2. Добавьте backend requests и limits, создайте HPA (50% CPU, 1–5 реплик).
3. Дайте нагрузку подом-генератором и увидьте рост реплик.
4. Через Ingress увидьте смену `hostname` в `/info`.
5. Остановите нагрузку и дождитесь возврата к одной реплике.
6. Уберите за собой: `kubectl delete namespace bootcamp`, `minikube stop`.

!!! success "✅ Как проверить себя"
    - `kubectl describe hpa backend-hpa -n bootcamp` — в Events есть и масштабирование вверх, и вниз.
    - В десяти запросах к `/info` под нагрузкой — минимум два разных `hostname`.
    - Число реплик выросло через 1–2 минуты после старта нагрузки и вернулось к 1 примерно через 5–7 минут после её остановки.

## Уровень 2 — мини-проект: поведение автомасштабирования

1. **Быстрее вниз.** Добавьте в HPA `behavior.scaleDown.stabilizationWindowSeconds: 60` и сравните, через сколько после остановки нагрузки реплики вернутся к одной.
2. **Плавнее вверх.** Ограничьте рост: не больше одного нового пода за 30 секунд (`behavior.scaleUp.policies`). Посмотрите, как теперь растёт число реплик.
3. **Две метрики.** Добавьте в HPA память с целью 70%. Посмотрите в `kubectl describe hpa`, как HPA выбирает число реплик по двум метрикам.
4. **OOMKilled.** Поставьте backend `limits.memory: "20Mi"` и посмотрите, что произойдёт. Найдите причину в `describe pod`. Верните нормальный лимит.

<details markdown="1">
<summary>💡 Подсказки</summary>

```yaml
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
    scaleUp:
      policies:
        - type: Pods
          value: 1
          periodSeconds: 30
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 50 }
    - type: Resource
      resource:
        name: memory
        target: { type: Utilization, averageUtilization: 70 }
```

- При нескольких метриках HPA считает число реплик для **каждой** и берёт **максимум**.
- OOMKilled: `kubectl describe pod` → `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`; в `kubectl get pods` растёт `RESTARTS`, затем `CrashLoopBackOff`.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] С окном 60 секунд реплики уменьшаются примерно через минуту после спада нагрузки.
- [ ] С политикой `scaleUp` реплики растут по одной примерно раз в 30 секунд.
- [ ] `kubectl get hpa` показывает две метрики в `TARGETS`.
- [ ] Вы видели `OOMKilled` и `Exit Code: 137` и вернули лимит памяти.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. HPA добавил 5 подов backend, а время ответа не улучшилось. Что могло пойти не так?</summary>

Узкое место не в backend. Каждый запрос `/api/hits` идёт в один под Redis: если тормозит он, лишние копии backend только увеличивают очередь к Redis. Другие варианты: поды нового backend не получают трафик (не проходят readiness), упираются в лимит CPU (throttling — `kubectl top` показывает потребление около лимита), или нода перегружена, и поды мешают друг другу. Масштабировать нужно то, что является узким местом, а для этого нужны метрики всей цепочки — задача мониторинга (Prometheus, Grafana).
</details>

<details markdown="1">
<summary>2. Как масштабировать backend не по CPU, а по числу запросов в секунду?</summary>

Нужен источник такой метрики и адаптер, который отдаст её HPA:

- приложение публикует счётчик запросов (наш backend уже отдаёт `http_requests_total` на `/metrics`);
- **Prometheus** собирает его;
- **Prometheus Adapter** (или KEDA со scaler'ом Prometheus) превращает его в метрику для HPA;
- в HPA — `type: Pods` с метрикой «запросов в секунду на под» и целевым значением, например 100.

Так масштабируют сервисы, которые упираются не в CPU, а в задержку или пропускную способность.
</details>

<details markdown="1">
<summary>3. Как выбрать requests и limits для нового сервиса, о котором вы ничего не знаете?</summary>

Начать с осторожных значений и **измерить**:

1. Запустить с умеренными requests и щедрыми limits.
2. Дать реалистичную нагрузку (нагрузочный тест) и смотреть `kubectl top` / графики в мониторинге за несколько дней.
3. Requests — примерно обычное потребление (часто 90-й перцентиль), лимит памяти — с запасом над пиками, лимит CPU — по необходимости (многие команды не ставят CPU limit вовсе, чтобы избежать throttling).
4. Пересматривать по мере роста.

Помогают **Vertical Pod Autoscaler** в режиме рекомендаций и метрики throttling и OOMKilled в мониторинге. Слишком большие requests — переплата за простаивающие ноды, слишком маленькие — нестабильность.
</details>
