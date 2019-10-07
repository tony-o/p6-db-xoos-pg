use DB::Xoos::Role::Model;

unit class Model::Customers does DB::Xoos::Role::Model['customers'];

has @.columns;
has @.relations;

method merged-method { 'success' }
