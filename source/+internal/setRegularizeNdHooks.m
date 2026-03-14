function setRegularizeNdHooks(hooks)
  % Set optional internal test hooks for regularizeNd.

  arguments
    hooks (1,1) struct
  end

  global REGULARIZEND_INTERNAL_HOOKS; %#ok<GVMIS>
  REGULARIZEND_INTERNAL_HOOKS = hooks;
end
