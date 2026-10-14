/// Notion ids for QA bug child cards (non-secret).
class QaBugTemplateConfig {
  const QaBugTemplateConfig({
    this.templatePageId = '8005c1ed-371f-44b4-b676-390c7f0b81d0',
    this.dataSourceId = 'c2046e5d-68c6-440d-83b3-4fdb2c1cefb6',
    this.databaseId = 'c49c7536-c2ac-4bf3-9f6e-bf368e3d76e3',
    this.bugTypeSelectName = 'Issues',
    this.bugStatusSelectName = 'Issues',
    this.parentRelationPropertyName = 'Parent task',
  });

  final String templatePageId;
  final String dataSourceId;
  final String databaseId;
  final String bugTypeSelectName;
  final String bugStatusSelectName;
  final String parentRelationPropertyName;
}
