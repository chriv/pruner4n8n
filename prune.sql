WITH params AS (
    SELECT
        10 AS keep_count,           -- Number of successes/failures to keep per flow
        '7 days'::interval AS age   -- Only touch flows older than this
)
DELETE FROM execution_entity
WHERE id IN (
    SELECT id
    FROM (
        SELECT
            e.id,
            ROW_NUMBER() OVER (
                PARTITION BY e."workflowId", e.status
                ORDER BY e."startedAt" DESC
            ) as rank,
            w."updatedAt"
        FROM execution_entity e
        JOIN workflow_entity w ON CAST(w.id AS VARCHAR) = e."workflowId"
        CROSS JOIN params p
        WHERE w."updatedAt" < NOW() - p.age
    ) ranked
    WHERE ranked.rank > (SELECT keep_count FROM params)
)
RETURNING id, "workflowId";
