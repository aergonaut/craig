Sequel.migration do
  change do
    create_table :listings do
      primary_key :id
      String :title
      String :url
    end
  end
end
