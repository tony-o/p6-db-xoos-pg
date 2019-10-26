use DB::Xoos::Model;

unit class Model::Customers does DB::Xoos::Model['customers'];

has @.columns;
has @.relations;

method merged-method { 'success' }
