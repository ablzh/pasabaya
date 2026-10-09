# Replication metadata may be present in a downloaded production database, but
# belongs to Litestream rather than the application's portable schema.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::SchemaDumper.ignore_tables += [ /\A_litestream_/ ]
end
