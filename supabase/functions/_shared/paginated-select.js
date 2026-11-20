const SELECT_PAGE_SIZE = 500;

export async function selectAllRows(createQuery) {
  const rows = [];
  for (let from = 0; ; from += SELECT_PAGE_SIZE) {
    const { data, error } = await createQuery().range(from, from + SELECT_PAGE_SIZE - 1);
    if (error) return { data: null, error };

    const page = data ?? [];
    rows.push(...page);
    if (page.length < SELECT_PAGE_SIZE) return { data: rows, error: null };
  }
}
