function clearRegularizeNdHooks()
  % Clear optional internal test hooks for regularizeNd.

  global REGULARIZEND_INTERNAL_HOOKS; %#ok<GVMIS>
  REGULARIZEND_INTERNAL_HOOKS = struct();
end
