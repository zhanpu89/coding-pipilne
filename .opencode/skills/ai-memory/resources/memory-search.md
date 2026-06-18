# 记忆搜索

遇到似曾相识的问题时。策略（自动降级）：

1. `search_summaries(query=关键词, use_fts=true)` — FTS5 精确匹配（错误信息/包名）
2. 无结果且向量可用 → `search_summaries(query=关键词, use_vector=true)` — 语义搜索
3. 降级 → `search_summaries_fts(query=关键词)` — 全文检索

找到后告诉用户"之前做过类似的事"并引用。
