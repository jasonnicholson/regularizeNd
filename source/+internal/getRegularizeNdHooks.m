function hooks = getRegularizeNdHooks()
  % Return optional internal test hooks for regularizeNd.

  global REGULARIZEND_INTERNAL_HOOKS; %#ok<GVMIS>
  if isempty(REGULARIZEND_INTERNAL_HOOKS)
    hooks = struct();
  else
    hooks = REGULARIZEND_INTERNAL_HOOKS;
  end
end
