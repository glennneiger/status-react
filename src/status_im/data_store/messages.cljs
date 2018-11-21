(ns status-im.data-store.messages
  (:require [cljs.tools.reader.edn :as edn]
            [re-frame.core :as re-frame]
            [status-im.constants :as constants]
            [status-im.data-store.realm.core :as core]
            [status-im.utils.core :as utils]
            [status-im.js-dependencies :as dependencies]))

(defn- transform-message [message]
  (-> message
      (update :message-type keyword)
      (update :content edn/read-string)))

(defn- get-by-chat-id
  ([chat-id]
   (get-by-chat-id chat-id 0))
  ([chat-id from]
   (let [messages (-> (core/get-by-field @core/account-realm :message :chat-id chat-id)
                      (core/sorted :timestamp :desc)
                      (core/page from (+ from constants/default-number-of-messages))
                      (core/all-clj :message))]
     (map transform-message messages))))

(defn- get-by-chat-and-messages-ids
  [chat-id message-ids]
  (when (seq message-ids)
    (let [messages (-> @core/account-realm
                       (.objects "message")
                       (.filtered (str "chat-id=\"" chat-id "\""
                                       (str " and (" (core/in-query "message-id" message-ids) ")")))
                       (core/all-clj :message))]
      (map transform-message messages))))

(def default-values
  {:to             nil})

(re-frame/reg-cofx
 :data-store/get-messages
 (fn [cofx _]
   (assoc cofx :get-stored-messages get-by-chat-id)))

(defn- sha3 [s]
  (.sha3 dependencies/Web3.prototype s))

(defn- get-unviewed-messages
  [public-key]
  (into {}
        (map (fn [[chat-id user-statuses]]
               [chat-id (into #{} (map :message-id) user-statuses)]))
        (group-by :chat-id
                  (-> @core/account-realm
                      (core/get-by-fields
                       :user-status
                       :and {:public-key public-key
                             :status     "received"})
                      (core/all-clj :user-status)))))

(re-frame/reg-cofx
 :data-store/get-unviewed-messages
 (fn [cofx _]
   (assoc cofx :get-stored-unviewed-messages get-unviewed-messages)))

(re-frame/reg-cofx
 :data-store/get-referenced-messages
 (fn [cofx _]
   (assoc cofx :get-referenced-messages get-by-chat-and-messages-ids)))

(defn- prepare-content [content]
  (if (string? content)
    content
    (pr-str content)))

(defn- prepare-message [message]
  (utils/update-if-present message :content prepare-content))

(defn save-message-tx
  "Returns tx function for saving message"
  [{:keys [message-id from] :as message}]
  (fn [realm]
    (core/create realm
                 :message
                 (prepare-message (merge default-values
                                         message
                                         {:from (or from "anonymous")}))
                 true)))

(defn delete-message-tx
  "Returns tx function for deleting message"
  [message-id]
  (fn [realm]
    (when-let [message (core/get-by-field realm :message :message-id message-id)]
      (core/delete realm message)
      (core/delete realm (core/get-by-field realm :user-status :message-id message-id)))))

(defn delete-messages-tx
  "Returns tx function for deleting messages with user statuses for given chat-id"
  [chat-id]
  (fn [realm]
    (core/delete realm (core/get-by-field realm :message :chat-id chat-id))
    (core/delete realm (core/get-by-field realm :user-status :chat-id chat-id))))

(defn message-exists? [message-id]
  (if @core/account-realm
    (not (nil? (.objectForPrimaryKey @core/account-realm "message" message-id)))
    false))
