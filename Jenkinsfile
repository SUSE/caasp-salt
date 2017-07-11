def targetBranch = env.getEnvironment().get('CHANGE_TARGET', env.BRANCH_NAME)

library "kubic-jenkins-library@${targetBranch}"

coreKubicProjectCi()
