(ns cljnix.builder-cli
  (:require
    [cljnix.utils :as utils]
    [cljnix.build :as build]
    [cljnix.check :as check]
    [clojure.data.json :as json]))

(defn- str->json
  [s]
  (json/read-str s :key-fn keyword))

(defn- check-main-class
  [args]
  (or
   (-> (zipmap [:lib-name :version :main-ns :compile-clj-opts :javac-opts :aliases] args)
          (update :compile-clj-opts str->json)
          (update :javac-opts str->json)
          (update :aliases str->json)
          (check/main-gen-class))
   (throw (ex-info "main-ns class does not specify :gen-class" {:args args}))))

; Internal CLI helpers
(defn -main
  [& [cmd & args]]
  (cond
    (= cmd "patch-git-sha")
    (apply utils/expand-shas! args)

    (= cmd "jar")
    (-> (zipmap [:lib-name :version :main-ns :compile-clj-opts :javac-opts :aliases] args)
        (update :compile-clj-opts str->json)
        (update :javac-opts str->json)
        (update :aliases str->json)
        (build/jar))

    (= cmd "uber")
    (do
      (check-main-class args)
      (-> (zipmap [:lib-name :version :main-ns :compile-clj-opts :javac-opts :aliases] args)
          (update :compile-clj-opts str->json)
          (update :javac-opts str->json)
          (update :aliases str->json)
          (build/uber)))

    (= cmd "check-main")
    (check-main-class args))

  (shutdown-agents))
