# frozen_string_literal: true

name 'noderings'

run_list 'test::default'

cookbook 'noderings', path: '.'
cookbook 'test', path: './test/cookbooks/test'

Dir.children('./test/cookbooks/test/recipes').grep(/\A[a-z].*\.rb\z/).sort.each do |recipe|
  recipe_name = File.basename(recipe, '.rb')
  named_run_list recipe_name.to_sym, "test::#{recipe_name}"
end
